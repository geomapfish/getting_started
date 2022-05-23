#!/bin/bash

Default=$'\e[0m'
Green=$'\e[1;32m'
Blue=$'\e[1;34m'
Red=$'\e[1;31m'

declare -i gmf_port
gmf_port=8484
gmf_host=`hostname`
using_proxy=false

abort()
{
  echo "${Red}Aborting GeoMapFish installation...${Default}"
  exit $1
}

# Requirements
##############

check()
{
  if command -v $1 > /dev/null
  then
    version=`$1 --version | head -1 2>&1`
    echo "${Green}[OK]  $version"
  else
    echo "${Red}[NOK] $1 NOT FOUND"
    echo "Please install the missing requirement."
    abort 91
  fi
}

checkuser()
{
  user=`whoami`
  if getent group docker | grep -q $user
  then
    echo "${Green}[OK]  User $user is in group docker"
  else
    echo "${Red}[NOK] User $user is not in group docker"
    abort 92
  fi
}

checkport()
{
  for i in {8484..8500}
  do
    used=`ss -tunlp | grep 'LISTEN' | grep $i | wc -l`
    if [ $used == 0 ]
    then
      gmf_port=$i
      echo "${Green}[OK]  Port $gmf_port will be used by GeoMapFish"
      return
    fi
  done
  echo "${Red}[NOK] Cannot find any free port between 8484 and 8500 to start GMF."  
  abort 93
}

echo
echo "${Default}---------------------------------------------------------------------------"
echo "${Default}Analysing requirements..."
check 'git'
check 'docker'
check 'docker-compose'
check 'python3'
check 'ss'
check 'sed'
check 'wget'
checkuser
checkport

# Proxy configuration
#####################

proxy()
{
  if ! [ -z ${!1} ]
  then 
    echo "${Green}$1: set to ${!1}"
    using_proxy=true
    return
  fi

  up=${1^^}
  if [ -z ${!up} ]
  then 
    echo "${Green}${1^^}: <not set>"
  else
    echo "${Green}${1^^}: set to ${!up}"
    using_proxy=true
  fi
}

echo
echo "${Default}--------------------------------------------------------------------------"
echo "${Default}If you are behind a proxy, the environment variables should be configured."
echo "Please verify that the following configuration is correct:"
proxy 'http_proxy'
proxy 'https_proxy'
proxy 'no_proxy'

read -p "${Default}Do you want to continue with this configuration? [y/n] " -n 1 -r cont
echo
if ! [[ $cont =~ ^[Yy]$ ]]
then
  abort 96
fi
 
# GeoMapFish configuration
##########################

echo
echo "${Default}--------------------------------------------------------------------------"
echo "Ok, let's configure GeoMapFish before we can install it:"
read -p "What version do you want to install? [2.6] " -r gmfver
gmfver=${gmfver:-2.6}
read -p "What is the fantastic name of your project? [my-super-gmf-app] " -r projname
projname=${projname:-my-super-gmf-app}
read -p "What coordinate system do you want to use? [2056] " -r srid
srid=${srid:-2056}
read -p "What extent do you want to use? [2420000,1030000,2900000,1350000] " -r extent
extent=${extent:-2420000,1030000,2900000,1350000}

# Git configuration
while [ -z $gitmail ]
do
  read -p "What email do you want to use for git? " -r gitmail
done
while [ -z "$gitname" ]
do
  read -p "What name do you want to use for git? " -r gitname
done

echo "${Green}Version to install: $gmfver"
echo "${Green}Project name      : $projname"
echo "${Green}Coordinate system : $srid"
echo "${Green}Extent            : $extent"
echo "${Green}Project Directory : $projname"
echo "${Green}Git Email         : $gitmail"
echo "${Green}Git Name          : $gitname"

echo "${Default}Please verify the configuration."
read -p "${Default}Do you want to start the installation? [y/n] " -n 1 -r cont
echo
if ! [[ $cont =~ ^[Yy]$ ]]
then
  abort 94
fi

# Start installation
####################

echo
echo "${Default}---------------------------------------------------------------------------"
echo "${Default}Downloading containers..."
docker pull camptocamp/geomapfish-tools:$gmfver
docker pull camptocamp/geomapfish:$gmfver
echo "${Green}OK."

echo
echo "${Default}---------------------------------------------------------------------------"

# Create project

echo ${gmfver:0:3}

if [[ ${gmfver:0:3} > "2.6" ]]
then
    create=create
    update=update
else
    create=c2cgeoportal_create
    update=c2cgeoportal_update
fi

echo "${Default}Creating GeoMapFish project..."
docker run --rm -ti --volume=$(pwd):/src --env=SRID=$srid --env=EXTENT="$extent" camptocamp/geomapfish-tools:$gmfver run $(id -u) $(id -g) /src pcreate -s $create $projname > install.log
echo "${Green}OK."

# Update project
echo "${Default}Updating project..."
docker run --rm -ti --volume=$(pwd):/src --env=SRID=$srid --env=EXTENT="$extent" camptocamp/geomapfish-tools:$gmfver run $(id -u) $(id -g) /src pcreate -s $update $projname >> install.log
echo "${Green}OK."

# Correct error in .eslintrc file
echo "${Default}Gathering positiveness..."
cd $projname
sed -i 's/code: 110/code: 200/g' geoportal/.eslintrc
echo "${Green}PERFECT!"

# Database configuration
########################

echo
echo "${Default}---------------------------------------------------------------------------"
echo "The first step is done. Now, we'll have to configure the database."
echo "If you want, a test database can be installed locally automatically."
echo "But if you already have configured one, it can be used."

read -p "Do you want to download and configure a database automatically? [y/n] " -n 1 -r cont
echo
if [[ $cont =~ ^[Yy]$ ]]
then
  echo "Configuring GeoMapFish Database..."
  
  dbhost=172.17.0.1
  # Check if the default network was overriden on this server
  if [ -f /etc/docker/daemon.json ]
  then
    dbhost=`sed -r 's/.*"bip" *\: *"([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+).*/\1/' /etc/docker/daemon.json`
  fi

  dbport=5432
  dbname=mydb
  dbuser=www
  dbpass=secret
  
  docker pull postgis/postgis:11-3.1
  docker kill gmf_postgis >> ../install.log 2>&1
  docker run --rm --name gmf_postgis -p 5432:5432 -v postgres:/var/lib/postgresql/data -e POSTGRES_PASSWORD=secret -d postgis/postgis:11-3.1 >> ../install.log
  # Wait the postgres startup
  sleep 20
  docker exec gmf_postgis bash -c "psql -U postgres -c 'CREATE DATABASE mydb;'" >> ../install.log
  docker exec gmf_postgis bash -c "psql -U postgres -d mydb -c 'CREATE EXTENSION postgis;'" >> ../install.log
  docker exec gmf_postgis bash -c "psql -U postgres -d mydb -c 'CREATE EXTENSION hstore;'" >> ../install.log
  docker exec gmf_postgis bash -c "psql -U postgres -d mydb -c \"CREATE USER www PASSWORD 'secret';\"" >> ../install.log
  docker exec gmf_postgis bash -c "psql -U postgres -d mydb -c 'CREATE SCHEMA main;'" >> ../install.log
  docker exec gmf_postgis bash -c "psql -U postgres -d mydb -c 'CREATE SCHEMA main_static;'" >> ../install.log
  docker exec gmf_postgis bash -c "psql -U postgres -d mydb -c 'GRANT ALL ON SCHEMA main TO www;'" >> ../install.log
  docker exec gmf_postgis bash -c "psql -U postgres -d mydb -c 'GRANT ALL ON SCHEMA main_static TO www;'" >> ../install.log
  echo "${Green}OK." 
else
  echo "${Default}Ok, let's configure your database connection then.."
  while [ -z $dbhost ]
  do
    read -p "Database Host: " -r dbhost
  done
  while [ -z $dbport ]
  do
    read -p "Database Port: " -r dbport
  done
  while [ -z $dbname ]
  do
    read -p "Database Name: " -r dbname
  done
  while [ -z $dbuser ]
  do
    read -p "Database User: " -r dbuser
  done
  while [ -z $dbpass ]
  do
    read -p "Database Password: " -r dbpass
  done
  
  echo "${Default}Please verify the configuration."
  echo "${Green}Database Host    : $dbhost"
  echo "${Green}Database Port    : $dbport"
  echo "${Green}Database Name    : $dbname"
  echo "${Green}Database User    : $dbuser"
  echo "${Green}Database Password: $dbpass"

  read -p "${Default}Do you want to continue? [y/n] " -n 1 -r cont
  echo
  if ! [[ $cont =~ ^[Yy]$ ]]
  then
    abort 95
  fi

fi

# Env configuration
###################

echo
echo "${Default}---------------------------------------------------------------------------"
echo "Configuring GeoMapFish project..."
sed -i "s/PGDATABASE=gmf_.*/PGDATABASE=${dbname}/g" env.project
sed -i "s/PGHOST=pg-gs.camptocamp.com/PGHOST=${dbhost}/g" env.project
sed -i "s/PGHOST_SLAVE=pg-gs.camptocamp.com/PGHOST_SLAVE=${dbhost}/g" env.project
sed -i "s/PGPORT=30100/PGPORT=${dbport}/g" env.project
sed -i "s/PGPORT_SLAVE=30101/PGPORT_SLAVE=${dbport}/g" env.project
sed -i "s/PGUSER=<user>/PGUSER=${dbuser}/g" env.project
sed -i "s/PGPASSWORD=<pass>/PGPASSWORD=${dbpass}/g" env.project
sed -i "s/PGSSLMODE=require/PGSSLMODE=prefer/g" env.project
sed -i "s/VISIBLE_WEB_HOST=localhost/VISIBLE_WEB_HOST=${gmf_host}/g" env.default
sed -i "s/8484/${gmf_port}/g" env.default
echo "${Green}OK."

# Initialize git and firt commit
echo "${Default}Committing first version..."
git init . >> ../install.log
git add . >> ../install.log
git config user.email "$gitmail" >> ../install.log
git config user.name "$gitname" >> ../install.log
git commit -m "First commit" >> ../install.log
echo "${Green}OK."

# Build the app
###############
echo "${Default}Compiling GeoMapFish project..."
./build >> ../install.log
echo "${Green}OK."

# Start the app
###############
echo "${Default}Starting GeoMapFish..."
docker-compose up -d
echo "${Green}OK."

# Fix proxy error
#################
fix_proxy()
{
  if [[ "$2" = 'top' ]]
  then
    echo "def _fix_case(env):
    if 'http_proxy' in env and 'HTTP_PROXY' in env:
        env.pop('http_proxy')
    if 'https_proxy' in env and 'HTTPS_PROXY' in env:
        env.pop('https_proxy')
    if 'no_proxy' in env and 'NO_PROXY' in env:
        env.pop('no_proxy')
    return env

" | cat - $1 > temp && mv temp $1
  else
    echo "

def _fix_case(env):
    if 'http_proxy' in env and 'HTTP_PROXY' in env:
        env.pop('http_proxy')
    if 'https_proxy' in env and 'HTTPS_PROXY' in env:
        env.pop('https_proxy')
    if 'no_proxy' in env and 'NO_PROXY' in env:
        env.pop('no_proxy')
    return env" >> $1
  fi

  sed -i "s/dict(os.environ)/_fix_case(dict(os.environ))/g" $1
}

if [ "$using_proxy" = true ] && [ "$gmfver" = "2.5" ]
then
  echo
  echo "${Default}---------------------------------------------------------------------------"
  echo "${Blue}There's a problem with proxies... This has been corrected in 2.6."
  containerprefix=`echo 'my-super-gmf-app' | sed -r 's/-/_/g'`
  c2cwsgiutilspath="/opt/c2cwsgiutils/"
  mkdir __fix
  docker cp ${containerprefix}_geoportal_1:/opt/alembic/env.py __fix/env.py
  docker cp ${containerprefix}_tilegeneration_slave_1:/app/tilecloud_chain/__init__.py __fix/__init__.py
  docker cp ${containerprefix}_geoportal_1:${c2cwsgiutilspath}/c2cwsgiutils/pyramid_logging.py __fix/pyramid_logging.py
  fix_proxy "__fix/pyramid_logging.py"
  fix_proxy "__fix/env.py" "top"
  fix_proxy "__fix/__init__.py"
  wget --quiet "https://raw.githubusercontent.com/geomapfish/getting_started/main/fix/${gmfver}/docker-compose.yaml" -O docker-compose.yaml
  echo "${Green}OK."

  echo "${Default}Restarting GeoMapFish..."
  docker-compose down && docker-compose up -d
fi

# Create schemas
################
echo "${Default}Initializing Database..."
docker-compose exec geoportal alembic --name=main upgrade head
docker-compose exec geoportal alembic --name=static upgrade head
echo "${Green}OK."

echo
echo "${Default}---------------------------------------------------------------------------"
echo "${Green}DONE!"
echo "${Default}The application can be accessed at https://$gmf_host:$gmf_port"
echo "The next things to do:"
echo "- Connect to the application with admin/admin and change the password."
echo "- Go at https://$gmf_host:$gmf_port/admin and add your own data."
echo "- Enjoy !"
