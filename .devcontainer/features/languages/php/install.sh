#!/bin/bash
set -e

echo "========================================="
echo "Installing PHP Development Environment"
echo "========================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Environment variables
export PHP_VERSION="${PHP_VERSION:-8.3}"
export COMPOSER_HOME="${COMPOSER_HOME:-/home/vscode/.cache/composer}"
export COMPOSER_CACHE_DIR="${COMPOSER_CACHE_DIR:-/home/vscode/.cache/composer/cache}"
export SYMFONY_CLI_HOME="${SYMFONY_CLI_HOME:-/home/vscode/.cache/symfony}"

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
sudo apt-get update && sudo apt-get install -y \
    software-properties-common \
    curl \
    git \
    unzip

# Add PHP repository
echo -e "${YELLOW}Adding PHP repository...${NC}"
sudo add-apt-repository -y ppa:ondrej/php
sudo apt-get update

# Install PHP
echo -e "${YELLOW}Installing PHP ${PHP_VERSION}...${NC}"
sudo apt-get install -y \
    php${PHP_VERSION} \
    php${PHP_VERSION}-cli \
    php${PHP_VERSION}-common \
    php${PHP_VERSION}-curl \
    php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-xml \
    php${PHP_VERSION}-zip \
    php${PHP_VERSION}-mysql \
    php${PHP_VERSION}-pgsql \
    php${PHP_VERSION}-sqlite3 \
    php${PHP_VERSION}-redis \
    php${PHP_VERSION}-gd \
    php${PHP_VERSION}-intl \
    php${PHP_VERSION}-bcmath

PHP_INSTALLED=$(php -version | head -n 1)
echo -e "${GREEN}✓ ${PHP_INSTALLED} installed${NC}"

# Install Composer
echo -e "${YELLOW}Installing Composer...${NC}"
EXPECTED_CHECKSUM="$(curl -sS https://composer.github.io/installer.sig)"
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
ACTUAL_CHECKSUM="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"

if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]; then
    echo -e "${RED}ERROR: Invalid installer checksum${NC}"
    rm composer-setup.php
    exit 1
fi

php composer-setup.php --quiet --install-dir=/usr/local/bin --filename=composer
rm composer-setup.php

COMPOSER_VERSION=$(composer --version)
echo -e "${GREEN}✓ ${COMPOSER_VERSION} installed${NC}"

# Install Symfony CLI
echo -e "${YELLOW}Installing Symfony CLI...${NC}"
curl -sS https://get.symfony.com/cli/installer | bash
sudo mv /home/vscode/.symfony5/bin/symfony /usr/local/bin/symfony
SYMFONY_VERSION=$(symfony version)
echo -e "${GREEN}✓ Symfony CLI ${SYMFONY_VERSION} installed${NC}"

# Install PHP development tools via Composer
echo -e "${YELLOW}Installing PHP development tools...${NC}"

# PHP_CodeSniffer
composer global require "squizlabs/php_codesniffer=*"
echo -e "${GREEN}✓ PHP_CodeSniffer installed${NC}"

# PHP CS Fixer
composer global require friendsofphp/php-cs-fixer
echo -e "${GREEN}✓ PHP CS Fixer installed${NC}"

# PHPStan
composer global require phpstan/phpstan
echo -e "${GREEN}✓ PHPStan installed${NC}"

# Psalm
composer global require vimeo/psalm
echo -e "${GREEN}✓ Psalm installed${NC}"

# PHPUnit
composer global require phpunit/phpunit
echo -e "${GREEN}✓ PHPUnit installed${NC}"

# Create cache directories
mkdir -p "$COMPOSER_HOME"
mkdir -p "$COMPOSER_CACHE_DIR"
mkdir -p "$SYMFONY_CLI_HOME"

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}PHP environment installed successfully!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Installed components:"
echo "  - ${PHP_INSTALLED}"
echo "  - ${COMPOSER_VERSION}"
echo "  - Symfony CLI ${SYMFONY_VERSION}"
echo "  - PHP_CodeSniffer"
echo "  - PHP CS Fixer"
echo "  - PHPStan"
echo "  - Psalm"
echo "  - PHPUnit"
echo ""
echo "Cache directories:"
echo "  - Composer: $COMPOSER_HOME"
echo "  - Composer cache: $COMPOSER_CACHE_DIR"
echo "  - Symfony: $SYMFONY_CLI_HOME"
