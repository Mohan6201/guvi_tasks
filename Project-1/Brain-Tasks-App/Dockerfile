# Use nginx as a lightweight web server
FROM nginx:alpine

# Copy the pre-built React app (as provided by the source repo) to nginx's html directory
COPY dist/ /usr/share/nginx/html/

# Serve on port 3000, per the task requirement ("Run application in port 3000")
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 3000

# Start nginx server
CMD ["nginx", "-g", "daemon off;"]
