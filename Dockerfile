FROM php:8.2-fpm

# Instalar dependencias
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    zip \
    unzip \
    nginx

# Limpiar cache
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Instalar extensiones PHP
RUN docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd

# Obtener Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Configurar directorio de trabajo
WORKDIR /var/www/html

# Copiar código del proyecto
COPY . /var/www/html

# Instalar dependencias del proyecto
RUN composer install --no-interaction --prefer-dist --no-dev

# Generar archivo .env si no existe
RUN if [ ! -f ".env" ]; then \
    cp .env.example .env || echo "No .env.example file found"; \
    fi

# Generar clave de la aplicación
RUN php artisan key:generate --force

# Optimizar configuración para producción
RUN php artisan config:cache && \
    php artisan route:cache && \
    php artisan view:cache

# Configurar permisos
RUN chmod -R 777 storage bootstrap/cache

# Configuración de Nginx
RUN echo 'server { \
    listen 8080; \
    root /var/www/html/public; \
    index index.php index.html; \
    location / { \
        try_files $uri $uri/ /index.php?$query_string; \
    } \
    location ~ \.php$ { \
        fastcgi_pass 127.0.0.1:9000; \
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name; \
        include fastcgi_params; \
    } \
}' > /etc/nginx/sites-available/default

# Script de inicio
RUN echo '#!/bin/bash \n\
service nginx start \n\
php-fpm' > /var/www/html/start.sh && \
    chmod +x /var/www/html/start.sh

# Exponer puerto
EXPOSE 8080

# Iniciar servicios
CMD ["/var/www/html/start.sh"]