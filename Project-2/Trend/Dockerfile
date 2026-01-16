# Use nginx as a lightweight web server
FROM nginx:alpine

# Copy the built React app from dist folder to nginx's html folder
COPY dist/ /usr/share/nginx/html/

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Expose port 80
EXPOSE 80

# Start nginx server
CMD ["nginx", "-g", "daemon off;"]
