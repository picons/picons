# PICONS

All the full resolution channel logos and their link to the actual channel (=serviceref) are kept up2date in this repository. The end result are picons for Enigma2 tuners and Kodi mediacenter in combination with a compatible PVR backend.

## BUILDING THE PICONS

Supported platforms: [Ubuntu](https://ubuntu.com/download) / [Debian](https://www.debian.org/distrib/) (recent versions) and [WSL2](https://learn.microsoft.com/en-us/windows/wsl/install) running either of the two.

> **WSL2 note:** Clone the repository into your **Linux home directory** (e.g. `~/picons`), not into a Windows-mounted path like `/mnt/c/`. Storing the files on the Linux filesystem gives significantly better I/O performance and avoids permission and symlink issues that arise when working across the WSL2/Windows boundary. You can still access the output files from Windows via the UNC path `\\wsl$\<distro>\home\<your-username>\picons\build-output` in File Explorer.

Download the repository by using one of the following commands:

```shell
# Install dependencies (Ubuntu / Debian / WSL2)
sudo apt-get install git binutils pngquant imagemagick librsvg2-bin jq

# Clone the repository
git clone https://github.com/picons/picons.git ~/picons
```

Next, copy the required files to the folder [build-input](build-input).

We will start the creation of the servicelist and the picons with the following commands:

```shell
cd ~/picons
./1-build-servicelist.sh
./2-build-picons.sh
```

Take a look at the folder [build-output](build-output) for the results.

TIP: To automate the building process, you can also use some of the following commands:

```shell
./1-build-servicelist.sh utf8snp
./1-build-servicelist.sh snp
./1-build-servicelist.sh srp
./2-build-picons.sh utf8snp
./2-build-picons.sh snp
./2-build-picons.sh srp
./2-build-picons.sh utf8snp-full
./2-build-picons.sh snp-full
./2-build-picons.sh srp-full
```

## SNP - SERVICE NAME PICONS

The idea behind SNP is that a simplified name derived from the channel name is used to lookup a channel logo. The idea and code was first implemented by OpenVIX for the Enigma2 tuners. Any developer currently using the serviceref method as a way to lookup a logo and would like to implement this alternative, can find the code used to generate the simplified name at the OpenVIX github [repository](https://github.com/OpenViX/enigma2/blob/master/lib/python/Components/Renderer/Picon.py#L88-L89).

## UTF8 SNP - UTF8 SERVICE NAME PICONS
The problem with Service Name Picons is that the code in Enigma2 only allowed a-z and 0-9 and no other characters such as `+` , `&`, `*`, `(`  and others This is ok for channels that use the western alphabet without accents or special characters but not for Arabic ( اسم قناتي ) or Bulgarian ( Диема ХД ) or even western European ( Áèíöúñ ).

Following a [dedicated OpenPLi commit](https://github.com/OpenPLi/enigma2/commit/2e7479e22eb2694fa1071f2429aad5721c663e1f) merged in April 2024, the picon code was updated to support unicode names, overcoming the limitations of SNP.

More details about UTF8 here: 
https://en.wikipedia.org/wiki/UTF-8


## FOLDER OVERVIEW

### ~/picons/build-input

#### Enigma2 servicelist creation

Copy your `enigma2` folder, probably located in `/etc` on your box into this folder.

#### TvHeadend servicelist creation

> **Prerequisites:** Before using the generator with TvHeadend, you must enable picons in the server by defining a destination folder under **Configuration -> General -> Base**. Without this step the generator will not work.

Use the servers API and directly ask the server about all channels by creating a file called `tvheadend.serverconf`. The file can contain the following values:

```shell
# hostname or ip address of tvheadend server (default: "localhost")
TVH_HOST="localhost"
# port of tvheadend API (default: 9981)
TVH_PORT="9981"
# tvheadend user name
TVH_USER=""
# tvheadend password of above user
TVH_PASS=""
# tvheadend http_root setting
TVH_HTTP_ROOT=""
```

Only the values which are different from the default values are required. For most people this will be a file with a single host name or host IP address.

```shell
TVH_HOST="my.tvheadend.server"
```

If you're running TvHeadend on the same machine, even an empty file (defaulting to `localhost`) should be sufficient.

#### VDR servicelist creation

If you're using VDR together with the Kodi addon xvdr, copy your `channels.conf` file to this folder.

#### Configuring which backgrounds to build

A file `backgrounds.conf` should be placed in this folder. If no file is found, the default file will be used. The default file is located at `build-source/config/backgrounds.conf` and is a good starting point: copy it to `build-input/` and uncomment the lines you want to build.

Syntax:

```
<resolution>;<resolution-padding>;<logotype>;<background>
```

The default configuration looks like this:

```shell
###########################################################
### Copy this file to the folder 'build-input'          ###
### Remove or comment the lines you don't want to build ###
###########################################################

# 70x53;62x45;dark;blue
# 70x53;62x45;dark;reflection
# 70x53;62x45;dark;transparent
# 70x53;62x45;dark;white
# 70x53;62x45;light;black
# 70x53;62x45;light;transparent

# 100x60;86x46;dark;blue
100x60;86x46;dark;reflection
100x60;86x46;dark;transparent
# 100x60;86x46;dark;white
# 100x60;86x46;light;black
100x60;86x46;light;transparent

# 220x132;190x102;dark;blue
220x132;190x102;dark;reflection
220x132;190x102;dark;transparent
# 220x132;220x132;dark;transparent
# 220x132;190x102;dark;white
# 220x132;190x102;light;black
220x132;190x102;light;transparent
# 220x132;220x132;light;transparent

# 256x256;226x226;light;transparent
# 256x256;226x226;dark;reflection
# 256x256;226x226;light;grey

# 400x170;370x140;dark;transparent

# 400x240;370x210;dark;blue
# 400x240;370x210;light;transparent
# 400x240;400x240;light;transparent

# 800x450;760x410;light;transparent
```

### ~/picons/build-output

This folder will contain the output from the build. Similar to the files [servicelist-enigma2-snp.txt](resources/samples/servicelist-enigma2-snp.txt) and [servicelist-enigma2-srp.txt](resources/samples/servicelist-enigma2-srp.txt). The picon binaries are also saved in this folder.

Possible output files and folders:

```yaml
binaries-utf8snp/
binaries-snp/
binaries-srp/
servicelist-enigma2-utf8snp.txt
servicelist-enigma2-snp.txt
servicelist-enigma2-srp.txt
servicelist-tvheadend-filemode-snp.txt
servicelist-tvheadend-filemode-srp.txt
servicelist-tvheadend-servermode-snp.txt
servicelist-tvheadend-servermode-srp.txt
servicelist-vdr-snp.txt
servicelist-vdr-srp.txt
```

### ~/picons/build-source

This is where all the channel logos go and how they are linked to the serviceref or a simplified version of the name. Backgrounds and the default `backgrounds.conf` file (in `build-source/config/`) can also be found in this directory.

### ~/picons/resources

Some additional files.
