FROM php:8.1-fpm

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

# Verificar si composer.json existe y manejar errores con mayor tolerancia
RUN if [ -f "composer.json" ]; then \
        composer install --no-interaction --prefer-dist --optimize-autoloader --no-dev || echo "Composer install failed, continuing anyway"; \
    else \
        echo "No composer.json found, skipping composer install"; \
    fi

# Intentar generar clave solo si el archivo artisan existe
RUN if [ -f "artisan" ]; then \
        php artisan key:generate --force || echo "Key generation failed, continuing anyway"; \
        php artisan config:cache || echo "Config cache failed, continuing anyway"; \
        php artisan route:cache || echo "Route cache failed, continuing anyway"; \
        php artisan view:cache || echo "View cache failed, continuing anyway"; \
    else \
        echo "No artisan file found, skipping Laravel commands"; \
    fi

# Configurar permisos si existe la carpeta storage
RUN if [ -d "storage" ]; then \
        chmod -R 777 storage bootstrap/cache || echo "Permission setting failed, continuing anyway"; \
    fi

# Configurar Nginx
RUN mkdir -p /var/www/html/docker

# Crear configuración de Nginx
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