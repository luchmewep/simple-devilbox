# Create and run a new Lumen app
function lumen_new() {
  lumen_version=""
  php_version=$(php_version)

  if [ -n "$1" ]; then
    name=$1
  else
    echo "👀 Please enter Lumen $(style "app name" underline bold) (default: $(style "app-random" bold blue)):"
    read -r name

    if [ -z "$name" ]; then
      name="app-$RANDOM"
    fi
  fi

  if [ -n "$2" ]; then
    lumen_version=$2
  else
    echo "👀 Please enter Lumen $(style "version" underline bold) (default: $(style "latest" bold blue)):"
    read -r lumen_version
  fi

  if [ -n "$3" ]; then
    php_version=$3
  else
    echo "Here are the available PHP containers: $(style php blue bold), $(style php54 blue bold), $(style php55 blue bold), $(style php56 blue bold), $(style php70 blue bold), $(style php71 blue bold), $(style php72 blue bold), $(style php73 blue bold), $(style php74 blue bold), $(style php80 blue bold), $(style php81 blue bold), $(style php82 blue bold)"
    echo "👀 Please enter $(style "PHP container" underline bold) to run the app on (default: $(style "$php_version" bold blue)):"
    read -r version

    if [ -n "$version" ] && is_php_container_valid "$version"; then
      php_version=$version
    fi
  fi

  # Validate if "php_version" input matches the current PHP container
  if ! is_php_container_valid "$php_version"; then
    echo_error "Invalid PHP container name: $(style "$php_version" bold)"
    stop_function
  fi

  if ! is_php_container_current "$php_version"; then
    current=$(php_version)
    echo_error "PHP container mismatch! You are currently inside $(style "$current" bold blue) container."
    echo "✋ To switch to $(style "$php_version" bold blue), exit this container first then run $(style "./up.sh $php_version" bold blue)."
    stop_function
  fi

  version=""
  if [ -n "$lumen_version" ]; then
    version=":^$lumen_version"

    # check if the version does not have a period
    if echo "$lumen_version" | grep -qv "\."; then
      version+=".0"
    fi
  fi

  cd /shared/httpd || stop_function

  style "🤝 Now creating your awesome Lumen app! 🔥🔥🔥\n" bold green

  mkdir "$name"

  cd "$name" || stop_function

  # create project
  composer create-project "laravel/lumen$version" "$name"

  # symlink and add devilbox config
  symlink "$name" "$name"
  if [ -n "$php_version" ]; then
    php_change "$name" "$php_version"
  else
    php_default "$name"
  fi

  cd "$name" || stop_function

  env=".env"
  # run migrate:fresh --seed if .env exists
  if [ -f $env ]; then
    lumen_replace_env_variables "$name"
    pa migrate --seed 2>/dev/null
  fi

  welcome_to_new_app_message "$name"
}

# Clone and run a Lumen app
function lumen_clone() {
  url=""
  php_version=$(php_version)
  branch="develop"

  if [ -n "$1" ]; then
    url=$1
  else
    echo "👀 Please enter $(style "Git URL" underline bold) of your Lumen app:"
    read -r url

    if [ -z "$url" ]; then
      echo_error "You provided an empty Git URL."
      stop_function
    fi
  fi

  if [ -n "$2" ]; then
    branch=$2
  else
    echo "👀 Please enter $(style "branch name" underline bold) to checkout at (default: $(style "develop" bold blue)):"
    read -r b

    if [ -n "$b" ]; then
      branch="$b"
    fi
  fi

  if [ -n "$3" ]; then
    name=$3
  else
    echo "👀 Please enter $(style "app name" underline bold) (default: $(style "app-random" bold blue)):"
    read -r name

    if [ -z "$name" ]; then
      name="app-$RANDOM"
    fi
  fi

  if [ -n "$4" ] && is_php_container_valid "$4"; then
    php_version=$4
  else
    echo "Here are the available PHP containers: $(style php blue bold), $(style php54 blue bold), $(style php55 blue bold), $(style php56 blue bold), $(style php70 blue bold), $(style php71 blue bold), $(style php72 blue bold), $(style php73 blue bold), $(style php74 blue bold), $(style php80 blue bold), $(style php81 blue bold), $(style php82 blue bold)"
    echo "👀 Please enter $(style "PHP container" underline bold) to run the app on (default: $(style "$php_version" bold blue)):"
    read -r version

    if [ -n "$version" ] && is_php_container_valid "$version"; then
      php_version=$version
    fi
  fi

  cd /shared/httpd || stop_function

  style "🤝 Now cloning your awesome Lumen app! 🔥🔥🔥\n" bold green

  mkdir "$name"

  cd "$name" || stop_function

  git clone "$url" "$name"
  git checkout "$branch" 2>/dev/null

  # symlink and add devilbox config
  symlink "$name" "$name"
  if [ -n "$php_version" ]; then
    php_change "$name" "$php_version"
  else
    php_default "$name"
  fi

  cd "$name" || stop_function

  # copy .env.example to .env
  env=".env"
  env_example=".env.example"
  if [ ! -f $env ] && [ -f $env_example ] ; then
    if cp "$env_example" "$env"; then
      lumen_replace_env_variables "$name"
      pa migrate --seed 2>/dev/null
    fi
  fi

  # install dependencies
  project_install

  welcome_to_new_app_message "$name"
}

# Replace all necessary env variables
function lumen_replace_env_variables() {
  file=".env"

  if [ -n "$1" ]; then
    name=$1
  else
    echo "👀 Please enter Lumen $(style "app name" underline bold) (default: $(style "app-random" bold blue)):"
    read -r name

    if [ -z "$name" ]; then
      name="app-$RANDOM"
    fi
  fi

  snake_name=${name//-/_}

  text_replace "^APP_NAME=Lumen$" "#APP_NAME=Lumen\nAPP_NAME=\"$name\"" "$file"
  text_replace "^APP_URL=http:\/\/localhost$" "#APP_URL=http:\/\/localhost\nAPP_URL=https:\/\/$name.dvl.to" "$file"

  if text_exists "^APP_KEY=$" "$file"; then
    pa key:generate 2>/dev/null
  fi

  ###
  ### DATABASE VARIABLES
  ###

  # This is for DB_HOST
  text_replace "^DB_HOST=127.0.0.1$" "#DB_HOST=127.0.0.1\nDB_HOST=mysql" "$file"

  # This is for DB_PORT
  text_replace "^DB_PORT=3306$" "#DB_PORT=3306\nDB_PORT=\"\$\{HOST_PORT_MYSQL\}\"" "$file"

  # This is for DB_USERNAME
  text_replace "^DB_USERNAME=homestead$" "#DB_USERNAME=homestead\nDB_USERNAME=root" "$file"

  # This is for DB_PASSWORD
  text_replace "^DB_PASSWORD=secret$" "#DB_PASSWORD=secret\nDB_PASSWORD=\"\$\{MYSQL_ROOT_PASSWORD\}\"" "$file"

  # This is for DB_DATABASE
  if text_replace "^DB_DATABASE=homestead$" "#DB_DATABASE=homestead\nDB_DATABASE=$snake_name" "$file"; then
    password=$MYSQL_ROOT_PASSWORD
    if [ -z "$password" ]; then
      mysql -u root -h mysql -e "create database $snake_name"
    else
      mysql -u root -h mysql -e "create database $snake_name" -p "$password"
    fi
  fi

  # This is for DB_PASSWORD
  text_replace "^DB_PASSWORD=$" "#DB_PASSWORD=\nDB_PASSWORD=\"\$\{MYSQL_ROOT_PASSWORD\}\"" "$file"

  ###
  ### REDIS VARIABLES
  ###

  # This is for REDIS_HOST
  if text_replace "^REDIS_HOST=127.0.0.1$" "#REDIS_HOST=127.0.0.1\nREDIS_HOST=redis" "$file"; then
    # This is for REDIS_PORT
    text_replace "^REDIS_PORT=6379$" "#REDIS_PORT=6379\nREDIS_PORT=\"\$\{HOST_PORT_REDIS\}\"" "$file"

    # This is for SESSION_DRIVER
    text_replace "^SESSION_DRIVER=file$" "#SESSION_DRIVER=file\nSESSION_DRIVER=redis" "$file"

    # This is for QUEUE_CONNECTION
    text_replace "^QUEUE_CONNECTION=sync$" "#QUEUE_CONNECTION=sync\nQUEUE_CONNECTION=redis" "$file"

    # This is for CACHE_DRIVER
    text_replace "^CACHE_DRIVER=file$" "#CACHE_DRIVER=file\nCACHE_DRIVER=redis" "$file"
  fi

  ###
  ### MAILHOG VARIABLES
  ###

  # This is for MAIL_HOST
  text_replace "^MAIL_HOST=smtp.mailtrap.io$" "#MAIL_HOST=smtp.mailtrap.io\nMAIL_HOST=mailhog" "$file"

  # This is for MAIL_PORT
  text_replace "^MAIL_PORT=2525$" "#MAIL_PORT=2525\nMAIL_PORT=\"\$\{HOST_PORT_MAILHOG\}\"" "$file"

  ###
  ### S3 VARIABLES
  ###

  # This is for AWS_ACCESS_KEY_ID
  text_replace "^AWS_ACCESS_KEY_ID=$" "#AWS_ACCESS_KEY_ID=\nAWS_ENDPOINT=\"http:\/\/minio:\$\{HOST_PORT_MINIO\}\"\nAWS_ACCESS_KEY_ID=\"\$\{MINIO_USERNAME\}\"" "$file"

  # This is for AWS_SECRET_ACCESS_KEY
  text_replace "^AWS_SECRET_ACCESS_KEY=$" "#AWS_SECRET_ACCESS_KEY=\nAWS_SECRET_ACCESS_KEY=\"\$\{MINIO_PASSWORD\}\"" "$file"

  # This is for AWS_BUCKET
  if text_replace "^AWS_BUCKET=$" "#AWS_BUCKET=\nAWS_BUCKET=$snake_name\nAWS_URL=\"http:\/\/$1.dvl.to:\$\{HOST_PORT_MINIO\}\/\$\{AWS_BUCKET\}\"" "$file"; then
    text_replace "^FILESYSTEM_DRIVER=local$" "#FILESYSTEM_DRIVER=local\nFILESYSTEM_DRIVER=s3" "$file"
    text_replace "^FILESYSTEM_DISK=local$" "#FILESYSTEM_DISK=local\nFILESYSTEM_DISK=s3" "$file"
  fi
}
