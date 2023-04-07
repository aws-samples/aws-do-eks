FROM php:5-apache
COPY index.php /var/www/html/index.php
RUN mkdir -p /var/www/html/php-apache; ln -s /var/www/html/index.php /var/www/html/php-apache/index.php; mkdir -p /var/www/html/hpa-example; ln -s /var/www/html/index.php /var/www/html/hpa-example/index.php
RUN chmod a+rx index.php
