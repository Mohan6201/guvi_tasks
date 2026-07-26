# Use nginx as a lightweight web server
FROM nginx:alpine

# Copy the built React app from dist folder to nginx's html folder
COPY dist/ /usr/share/nginx/html/

# The vendor-shipped production build (no source available to rebuild)
# has a baked-in bug: product thumbnails are requested from a broken
# relative path `undefined/images/<name>.png` - an unset base-URL env
# var that got stringified as "undefined" at build time. Recreate that
# exact path here (not in the gitignored dist/ folder) so the fix is
# git-tracked and survives fresh clones / Jenkins builds, not just this
# machine. Vite doesn't alter image bytes when hashing, only renames -
# it always appends a FIXED 8-character hash (from a base64url-like
# alphabet that itself can contain "-", e.g. "p_img47-C0-ZYjIt.png" is
# "p_img47" + hash "C0-ZYjIt") - so stripping exactly the last 9
# characters ("-" + 8-char hash) before the extension recovers the
# plain name, unlike a naive "strip after the last hyphen" approach
# which breaks whenever the hash itself contains a hyphen.
RUN mkdir -p /usr/share/nginx/html/undefined/images && \
    for f in /usr/share/nginx/html/assets/*.png; do \
      plain=$(basename "$f" | sed -E 's/.{9}\.png$/.png/'); \
      cp "$f" "/usr/share/nginx/html/undefined/images/$plain"; \
    done

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Expose port 80
EXPOSE 80

# Start nginx server
CMD ["nginx", "-g", "daemon off;"]
