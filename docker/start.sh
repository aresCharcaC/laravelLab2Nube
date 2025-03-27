cat > docker/start.sh << 'EOF'
#!/bin/bash
service nginx start
php-fpm
EOF