# AWS Deployment Guide - Brain Tasks App

Everything in this project is driven by a single `.env` file. No script
hardcodes an account ID, region, cluster name, or repo name - change a
value once in `.env` and every script/buildspec picks it up.

## 0. One-time local prerequisites

- AWS CLI v2, configured (`aws sts get-caller-identity` should work)
- `kubectl`
- Docker Desktop running (for local image build/testing only - CodeBuild
  builds the production image, Docker Desktop is not required for AWS
  deployment itself)

Note: this app has no source code or `package.json` - `dist/` is the
pre-built output copied verbatim from the assigned repo
(https://github.com/Vennilavanguvi/Brain-Tasks-App.git - see the source
note in README.md for why). There is nothing to `npm install`/`npm run
build`; Docker just copies `dist/` into nginx.

```bash
cd Brain-Tasks-App
cp .env.example .env
```

Open `.env` and fill in real values - at minimum `AWS_ACCOUNT_ID`,
`AWS_REGION`, and `GITHUB_REPO_URL`. `.env` is gitignored; never commit it.

## Why this sequence

Each stage's script assumes the previous stage's resources already exist:
IAM roles are the trust anchor for everything else, ECR must exist before
CodeBuild can push to it, EKS must exist before CodeBuild can deploy to
it, and CodePipeline just wires the pieces already created together.
Skipping ahead will fail with a clear "role/repo/cluster not found" error.

```
iam-setup.sh -> ecr-setup.sh -> eks-setup.sh -> codebuild-setup.sh -> (manual: GitHub connection) -> codepipeline-setup.sh
```

## 1. IAM roles

```bash
chmod +x iam-setup.sh && ./iam-setup.sh
```

Creates (idempotent - safe to re-run):
- `EKSClusterRole` - lets EKS manage the cluster control plane
- `EKSNodeRole` - lets EC2 worker nodes join the cluster and pull from ECR
- `CodeBuildServiceRole` - lets CodeBuild push to ECR, write CloudWatch
  logs, and (for the deploy project) describe/talk to the EKS cluster
- `CodePipelineServiceRole` - lets CodePipeline invoke CodeBuild and read
  the S3 artifact bucket

## 2. ECR (Registry)

```bash
chmod +x ecr-setup.sh && ./ecr-setup.sh
```

Creates the `$ECR_REPOSITORY_NAME` repository with image scanning on push,
and logs your local Docker in to it (useful for step 2b, manual testing).

**2b. Manual local build/test (optional, proves the Dockerfile works):**

```bash
docker build -t $APP_NAME:$IMAGE_TAG .
docker run -d -p 3000:3000 --name brain-tasks-test $APP_NAME:$IMAGE_TAG
# visit http://localhost:3000 - title should read "Brain Task", then:
docker stop brain-tasks-test && docker rm brain-tasks-test
```

## 3. EKS (Kubernetes)

```bash
chmod +x eks-setup.sh && ./eks-setup.sh
```

Creates the `$EKS_CLUSTER_NAME` cluster (~10-15 min) and a managed node
group `$EKS_NODE_GROUP_NAME` (~5-10 min), points local `kubectl` at it,
and grants both your IAM identity and the CodeBuild deploy role
cluster-admin access via EKS access entries (no manual `aws-auth`
ConfigMap editing needed). Ends by printing `kubectl get nodes` -
confirm nodes show `Ready` before moving on.

## 4. CodeBuild (Build + Deploy projects)

```bash
chmod +x codebuild-setup.sh && ./codebuild-setup.sh
```

Creates two projects, both reading their config as CodeBuild
environment variables injected straight from `.env`:

- **`$CODEBUILD_BUILD_PROJECT`** (`buildspec.yml`, privileged mode on):
  `docker build` (from the already-committed `dist/`) -> push to ECR ->
  writes `image-uri.txt` / `imagedefinitions.json` as artifacts.
- **`$CODEBUILD_DEPLOY_PROJECT`** (`buildspec-deploy.yml`): installs
  `kubectl`, points it at `$EKS_CLUSTER_NAME`, renders `k8s/*.yaml`
  templates with the real image URI, applies them, waits for rollout,
  prints the LoadBalancer hostname.

If the source repo is a monorepo (this project lives at
`Project-1/Brain-Tasks-App` inside `guvi_tasks`), `SOURCE_DIR` in `.env`
tells both buildspecs which subdirectory to work from.

**Manual test of the build project alone:**
```bash
aws codebuild start-build --project-name $CODEBUILD_BUILD_PROJECT --region $AWS_REGION
```
Watch progress in CloudWatch Logs group `$CLOUDWATCH_LOG_GROUP`.

## 5. GitHub connection (one manual step - cannot be scripted)

AWS Console -> **Developer Tools -> Settings -> Connections** ->
**Create connection** -> GitHub -> authorize the AWS Connector app for
your repo -> wait for status **Available** -> copy the connection ARN
into `CODESTAR_CONNECTION_ARN` in `.env`.

This is a one-time OAuth handshake; AWS does not expose a CLI way to
grant GitHub access non-interactively.

## 6. CodePipeline

```bash
chmod +x codepipeline-setup.sh && ./codepipeline-setup.sh
```

Creates `$CODEPIPELINE_NAME` with three stages:
1. **Source** - `CodeStarSourceConnection` action, pulls `$GITHUB_BRANCH`
   from `$GITHUB_REPO_URL` via the connection from step 5.
2. **Build** - invokes `$CODEBUILD_BUILD_PROJECT`.
3. **Deploy** - invokes `$CODEBUILD_DEPLOY_PROJECT` with the Build
   stage's output artifact as input.

> **Why a second CodeBuild project instead of CodeDeploy/`appspec.yml`?**
> AWS CodeDeploy only supports EC2/On-Premises, Lambda, and ECS as
> deployment targets - **not EKS**. A CodePipeline "Deploy to EKS via
> CodeDeploy" stage, as the assignment brief describes it, isn't something
> AWS actually offers. The documented, working pattern is a CodeBuild
> project that runs `kubectl apply` as the Deploy action, which is what
> `buildspec-deploy.yml` + this pipeline do. An `appspec.yml` and its
> CodeDeploy lifecycle-hook scripts were kept around briefly as reference
> for what each deploy step conceptually does, but have since been
> removed entirely, since CodeDeploy can't target EKS at all and keeping
> them risked implying a deploy path that doesn't actually exist.

Trigger a run:
```bash
aws codepipeline start-pipeline-execution --name $CODEPIPELINE_NAME --region $AWS_REGION
```

Any push to `$GITHUB_BRANCH` on `$GITHUB_REPO_URL` will also trigger it
automatically from then on.

## 7. Verify

```bash
kubectl get pods -n $K8S_NAMESPACE -l app=$APP_NAME
kubectl get service ${APP_NAME}-service -n $K8S_NAMESPACE
kubectl get service ${APP_NAME}-service -n $K8S_NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

The LoadBalancer hostname is a DNS name, not an ARN - to get the actual
ARN (needed for submission), match it against the **classic** ELB API, not
`elbv2` - a plain `type: LoadBalancer` Service on EKS with no AWS Load
Balancer Controller installed provisions a Classic Load Balancer, which
`elbv2` (Application/Network Load Balancers only) can't see at all and
will just return an empty result for:
```bash
aws elb describe-load-balancers --region $AWS_REGION \
  --query "LoadBalancerDescriptions[?contains(DNSName, '<hostname-prefix-from-above>')].LoadBalancerName" --output text
# then: arn:aws:elasticloadbalancing:$AWS_REGION:$AWS_ACCOUNT_ID:loadbalancer/<name>
```

## 8. Monitoring (CloudWatch)

- CodeBuild logs: CloudWatch Logs group `$CLOUDWATCH_LOG_GROUP` (build
  and deploy projects both log here - filter by log stream/project name).
- Application/pod logs: `kubectl logs -n $K8S_NAMESPACE -l app=$APP_NAME -f`
  (add a CloudWatch Container Insights / Fluent Bit DaemonSet if you also
  want pod logs to land in CloudWatch Logs, not just `kubectl logs`).

## Manual/local Kubernetes deploy (alternative to the pipeline)

```bash
chmod +x k8s/deploy.sh && ./k8s/deploy.sh
```

Does the same render -> apply -> wait -> print-LB-URL sequence as
`buildspec-deploy.yml`, but from your machine, useful for testing before
wiring up the full pipeline.

## Teardown (avoid ongoing charges)

```bash
kubectl delete -f k8s/rendered/service.yaml
aws eks delete-nodegroup --cluster-name $EKS_CLUSTER_NAME --nodegroup-name $EKS_NODE_GROUP_NAME --region $AWS_REGION
aws eks wait nodegroup-deleted --cluster-name $EKS_CLUSTER_NAME --nodegroup-name $EKS_NODE_GROUP_NAME --region $AWS_REGION
aws eks delete-cluster --name $EKS_CLUSTER_NAME --region $AWS_REGION
aws codepipeline delete-pipeline --name $CODEPIPELINE_NAME --region $AWS_REGION
aws codebuild delete-project --name $CODEBUILD_BUILD_PROJECT --region $AWS_REGION
aws codebuild delete-project --name $CODEBUILD_DEPLOY_PROJECT --region $AWS_REGION
aws ecr delete-repository --repository-name $ECR_REPOSITORY_NAME --region $AWS_REGION --force
```

EKS control plane (~$0.10/hr) and the EC2 worker nodes are the main
ongoing costs - delete the node group and cluster as soon as you're done
verifying, if this is just for assessment purposes.
