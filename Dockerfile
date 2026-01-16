# Use nginx as the base image for serving the React app
FROM nginx:alpine

# Remove the default nginx configuration
RUN rm /etc/nginx/conf.d/default.conf

# Copy custom nginx configuration with health check
COPY nginx.conf /etc/nginx/conf.d/

# Copy the build folder to nginx's html directory
COPY build/ /usr/share/nginx/html/

# Expose port 80
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
