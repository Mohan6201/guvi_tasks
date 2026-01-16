# Use nginx as a lightweight web server
FROM nginx:alpine

# Copy the built React app to nginx's html directory
COPY dist/ /usr/share/nginx/html/

# Copy custom nginx configuration (optional)
# COPY nginx.conf /etc/nginx/nginx.conf

# Expose port 80
EXPOSE 80

# Start nginx server
CMD ["nginx", "-g", "daemon off;"]
