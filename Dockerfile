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

# Instalar dependencias del proyecto
RUN composer install --optimize-autoloader --no-dev

# Generar clave de la aplicación
RUN php artisan key:generate

# Optimizar configuración para producción
RUN php artisan config:cache && \
    php artisan route:cache && \
    php artisan view:cache

# Configurar permisos
RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache

# Exponer puerto
EXPOSE 8080

# Configurar Nginx
COPY docker/nginx.conf /etc/nginx/sites-available/default
RUN mkdir -p /var/www/html/docker

# Script de inicio
COPY docker/start.sh /var/www/html/docker/start.sh
RUN chmod +x /var/www/html/docker/start.sh

# Iniciar servicios
CMD ["/var/www/html/docker/start.sh"]