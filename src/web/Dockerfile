# Start from official Nginx Alpine image for minimal footprint
# IE2: nginx v1.24-alpine
FROM nginx:1.24-alpine

# Set environment variables for Nginx configuration
ENV NGINX_WORKER_PROCESSES=auto \
    NGINX_WORKER_CONNECTIONS=1024

# Install additional required packages
# IE2: curl latest
RUN apk add --no-cache curl

# Create nginx user and group with specific UID/GID for security
RUN addgroup -g 101 -S nginx \
    && adduser -S -D -H -u 101 -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx

# Create required directories with proper permissions
RUN mkdir -p /usr/share/nginx/html \
    && mkdir -p /var/cache/nginx \
    && mkdir -p /var/log/nginx \
    && chown -R nginx:nginx /usr/share/nginx/html \
    && chown -R nginx:nginx /var/cache/nginx \
    && chown -R nginx:nginx /var/log/nginx \
    && chmod 755 /usr/share/nginx/html \
    && chmod 755 /var/cache/nginx \
    && chmod 755 /var/log/nginx

# Copy Nginx configuration files
COPY config/nginx/nginx.conf /etc/nginx/nginx.conf
COPY config/security-headers.conf /etc/nginx/conf.d/security-headers.conf

# Copy static content
COPY src/index.html /usr/share/nginx/html/index.html

# Set proper permissions for configuration and content files
RUN chown -R nginx:nginx /etc/nginx \
    && chmod 644 /usr/share/nginx/html/index.html \
    && chmod 644 /etc/nginx/nginx.conf \
    && chmod 644 /etc/nginx/conf.d/security-headers.conf

# Remove default Nginx configuration and unnecessary files
RUN rm -rf /etc/nginx/conf.d/default.conf \
    && rm -rf /var/cache/apk/*

# Configure healthcheck
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

# Expose HTTP port
EXPOSE 80

# Switch to non-root user
USER nginx

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]