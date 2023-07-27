# Getting Started with GeoMapFish - **TL; DR**

Open a linux console, and execute the following commands:
```
wget https://raw.githubusercontent.com/geomapfish/getting_started/main/install.sh
chmod +x install.sh
./install.sh
```

Then, follow the instructions.  

Your application is at https://<replace_with_your_computer_name>:8484.  
The admin interface is at https://<replace_with_your_computer_name>:8484/admin.  
The default credentials are admin/admin.

That's it!  
Enjoy :-)

___
# Getting Started with GeoMapFish - **Long version**

## Introduction

This page goes through the basic, required steps to create your first GeoMapFish application from scratch. It is based on **Version 2.5**. To learn what GeoMapFish is all about, please visit our [homepage](https://geomapfish.org/).

This guide is written for Linux systems. GeoMpaFish works on Windows systems as well, but as the community is using Linux in a large majority, there is no guide for Windows at the moment.

___
## **Step 1: Configure proxies**

If you are behind a corporate proxy, you will have to configure the proxies. This can be done like this:

```
export http_proxy=http://user:password@proxy_host:proxy_port
export https_proxy=http://user:password@proxy_host:proxy_port
export no_proxy=localhost,127.0.0.1,mydomain.ch
```

___
## **Step 2: Install requirements**

The first step is to install the GeoMapFish requirements.  
You will need to have the following components installed on your system:

- Git
- Python >= 3.7 with pyyaml
- Docker >= 17.05
- Docker-Compose

You can install the requirements by using your package manager.  
For example, on Debian, you can do the following:

```
apt update && apt install -y git python3 docker docker-compose
```

In order to be able to use GeoMapFish, your linux user mut be part of the docker group:

```
usermod -aG docker myuser
```

___
## **Step 3: Prepare database**

To store its configuration, GeoMapFish is using a PostgreSQL database with the following required extensions:

- PostgreSQL >= 9.1
- PostGIS >= 2.1
- hstore
- pg_trgm

**If you don't have any Postgres database yet, the installation script can download and configure one for you. If this is what you want, you can jump directly to Step 4**.

Otherwise, if you want to use you own database, the installation script will help you to configure GeoMapFish in order to use it, but you will have to execute first some commands on the database manually.

### 1. Create database
```
CREATE DATABASE mydb;
```

### 2. Activate extensions:
```
CREATE EXTENSION postgis;
CREATE EXTENSION hstore;
CREATE EXTENSION pg_trgm;
```

### 3. Create User, Schema, and configure rights:
```
CREATE USER www PASSWORD 'secret';
CREATE SCHEMA main;
CREATE SCHEMA main_static;
GRANT ALL ON SCHEMA main TO www;
GRANT ALL ON SCHEMA main_static TO www;
```

___
## **Step 4: Install GeoMapFish**

You are now ready to install GeoMapFish.  
Let's do it!

### 1. Download the installation script
```
wget https://raw.githubusercontent.com/geomapfish/getting_started/main/install.sh
```

### 2. Make it executable
```
chmod +x install.sh
```

### 3. Execute it
The installation script will guide you through the configuration process.  
Just start the script, and follow the instructions:
```
./install.sh
```

The questions asked by the installation script should be self-explanatory.  
If there's something you don't understand, feel free to ask for help at contact@geomapfish.org.  
If you're encountering an error during the installation, please join the generated file `install.log` to your email.

___
## **Step 5: First start**

You should now have a working instance of GeoMapFish.  
Congratulations!

Now, it's time to start your application for the first time. You should be able to do this at [https://hostname:port]() (for exemple https://<replace_with_your_computer_name>:8484).

Because your new instance of GeoMapFish doesn't have any valid SSL certificat yet, you will very likely get a `NET::ERR_CERT_AUTHORITY_INVALID` warning from your Browser:

![SSL Error](img/ssl_error.png)

For the moment, just ignore it and proceed to website anyway.  
You will be able to see the application:

![First start](img/first_start.png)

___
## **Step 6: Login & change admin password**

On the right side of the application, you will see a toolbar.  
At the very top of this toolbar, you can login to your application.

The default credentials are:
- Username : **admin**
- Password : **admin**

![Admin Login](img/admin_login.png)

Once logged in, you will have to change the admin password:

![Change Password](img/change_pass.png)

Ok, there you are !

![Admin connected](img/admin_connected.png)

Well... it's quite empty for now.  
Let's add some data!

___
## **Step 7: Add basemap**

If you want a nice mapping application, I guess you need a background map to get started.  
Let's add a WMTS Layer from Swisstopo in order to use it as Basemap.

### 1. Connect to the admin interface
It is available at [https://<replace_with_your_computer_name>:port/admin]() (for exemple https://<replace_with_your_computer_name>:8484/admin).  
As you are already logged in to GeoMapFish with the **admin** user, you are also automatically authenticated to the administration interface.

### 2. Add a new WMTS Layer
Navigate to the `WMTS Layers` tab:

![WMTS Empty](img/wmts_empty.png)

Create a new WMTS Layer, and configure it as follows:

- **Name**: The name of the layer in GeoMapFish: `Swisstopo Pixelkarte Color`
- **GetCapabilities URL**: The URL that will be used to get the Capabilities of the configured WMTS Layer: 
  https://wmts.geo.admin.ch/1.0.0/WMTSCapabilities.xml. 
- **WMTS layer name**: The identifier if the WMTS layer in the Capabilities: `ch.swisstopo.pixelkarte-farbe`. 
- **Public**: Defines if this layer will be publicly available in the geoportal, or if it will have restricted access: `checked`
- **Interfaces**: Defines in which interface this Layer will be available: `desktop` and `mobile`

![WMTS Color](img/wmts_color.png)

Click `Submit`.

### 3. Add the Layer to background layers
Navigate to the `Layer groups` tab:

![Layer groups](img/groups.png)

A layer group, with the name `background`, is already configured. This group is used to load available background maps in the application. The layers linked to this group will be visible in the application under the `basemap selector`:

![Basemap Selector](img/basemap_selector.png)

Let's add our new WMTS Layer to this group.  
Open the layer group by double-clicking on it. In the `Children` area, select the WMTS Layer `Swisstopo Pixelkarte Color` and to add it the the group:

![Add Basemap](img/add_basemap.png)

Click `Submit`.

### 4. Refresh the application

Go back to your geoportal (https://<replace_with_your_computer_name>:8484), and refresh the website with `F5`. The new basemap should now be available in the background selector:

![With Basemap](img/with_basemap.png)

Congratulations, you've configured your first basemap in you geoportal!

___
## **Step 8: Add you own data**
