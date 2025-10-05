# ISSUES

When submitting an issue, make sure you follow these rules:

- Put entries to `srp.index`, `snp.index` or `utf8snp.index` inside fenced code blocks. You can create fenced code blocks by placing a new line with three backticks ` ``` ` before and after the code block. ([READ THIS GUIDE](https://help.github.com/articles/creating-and-highlighting-code-blocks/))
- Logos should be inside an archive, correctly named (see below). Share the link.

Do you like copy/paste? We do too, make sure your issue is easily copy/pasted.

# NAMING

__srp.index:__

Contains partial Enigma2 service references, establishing a link between the actual logos in this repository.

- UPPERCASE
- Only the part `296_5_85_C00000` is used, the parts `1_0_1_` and `_0_0_0` must be removed.

Example entries in srp.index

```
65_251C_D5_820000=travelchannel
13F_1_1_1862FEF=travelchannel-lichoridas
1AD_9_3_130000=nationalgeographicwild
```
The parts before the `=` sign are the partial service references.
The parts after the `=` sign are the logos on **this repository**. This is not the channel name.


__utf8snp.index:__

Contains utf8 channel names establishing a link between the actual logos in this repository. With the exception of system characters, the names will match the channel name. We use lowercase.
This project cannot use the `=` sign, so please use the SRP entry for such channels.

Example utf8snp name:

- `5*` => `5*`
- `Sony Channel +1` => `sony channel +1`
- `BT Sport//ESPN` => `bt sportespn`


__snp.index:__

Contains simplified channel names according to OpenVIX implementation, called SNP, establishing a link between the actual logos in this repository.

SNP names are constructed by the following rules:

- lowercase
- letters `a to z`
- numbers `0 to 9`
- replace `&` with `and`
- replace `+` with `plus`
- replace `*` with `star`

This obviously means that spaces and other characters are not allowed.

Example snp name:

- `5*` => `5star`
- `Sony Channel +1` => `sonychannelplus1`
- `BT Sport//ESPN` => `btsportespn`


__Logo:__

- LOWERCASE
- NO spaces, fancy symbols or `.-+_*`, except for the exceptions below.
- Time sharing channels are seperated by `_`.
- If the logo name you wish to use already exists, add a unique identifier like `-trechuhipe`, this is a pronounceable random 10 character string generated using [this](http://www.generate-password.com) password generator. Grouping logos together using the same unique identifier is possible.
- Filetype `svg` is the way to go, otherwise `png`.
- The resolution doesn't matter for `svg`, for `png` try to get it > 800px.
- When submitting `svg` files, make sure to convert `text` to `paths`.
- It's not allowed for `svg` files to contain base64 encoded images.
- Try to make `svg` files rsvg compatible, they definately need to open in Inkscape, so no Adobe Illustrator only compatibility.
- If it's possible to easily trace your png with Inkscape, only the `svg` is allowed. In most cases this is possible.
- Quality should be as high as possible.
- Background should be transparent.
- No empty space around the logo.
- A `default` version of a logo should get the identifier `.default` at the end of the filename, additional types are possible, by using for example `.light`, `.dark`, `.black` or `.white` as an identifier.

Explanation of logo types:
```
default=standard logo as used by the tv station, looks good on background intended by tv station, mostly white background
light=modified default logo that makes darker parts lighter, looks good on darker backgrounds
dark=modified default logo that makes lighter parts darker, looks good on lighter backgrounds
white=fully white logo, no colors allowed (indexed 1-bit, black/white), looks good on dark backgrounds
black=fully black logo, no colors allowed (indexed 1-bit, black/white), looks good on light backgrounds
```

# SAMPLES

### srp.index

New additions can go at the top. Best to cleanup the old entries.

```
1005_29_46_E080000=eurosporthd
1006_29_46_E080000=discoveryhdshowcase
1007_43_46_E080000=tvnorgehd
1008_29_46_E080000=bbchd
100E_3_1_E083163=viasat6
1015_1D4C_FBFF_820000=discoveryhd
1018_1D4C_FBFF_820000=cielohd
1018_3_1_E083163=novacinema
10_1_85_C00000=fox
10_1_85_FFFF0000=fox
1019_7DC_2_11A0000=skymoviesboxoffice-trechuhipe
1019_7EF_2_11A0000=skymoviesboxoffice-trechuhipe
101B_7DC_2_11A0000=skymoviesboxoffice-trechuhipe
101B_7EF_2_11A0000=skymoviesboxoffice-trechuhipe
101_E_85_C00000=skybundesligahd-racratridr
```


### utf8snp.index

New additions can go at the top. Best to cleanup the old entries.

```
kabelio 5 uk=channel5
5 +1=channel5plus1
5+1=channel5plus1
channel 5 +1=channel5plus1
5_14_22FC_EEEE0000=channel5thailand
kanal yek hd=channelone
kanal yek sd=channelone
channel s=channels
chstv=channels
channels 24=channels24
al malakoot sat – the kingdom sat الملكوت سات=almalakoot
```

In the above examples, 
The parts before the `=` sign are the channel's utf8snp names.
The parts after the `=` sign are the logos on **this repository**. These are not the channel names.

**Channels with identical names**

When there are different channels but with identical snp names, we distinguish between them by using srp references for some of them. For example there are two different channels on 28.2 but have the same name `sky comedy hd`. The entries in the index to ensure they have linkages to different logos are:

```
EEB_7EE_2_11A0000=skycinemacomedy
sky comedy hd=skycomedy
```

You **cannot** have two different `utf8snp names` that point to different `logos on this repository`. In the example below, only the logo in the topmost line will be used to create a picon.
```
sky comedy=skycomedy
sky comedy=skycinemacomedy
```


### snp.index

New additions can go at the top. Best to cleanup the old entries.

```
2843_7FE_2_11A0000=bbcparliament
100procentnl=100procentnl
cplusalademande=canalplusalademande-thukalafri
cpluscomedia=canalpluscomedia-radubrekac
cpluscomediahd=canalpluscomediahd-radubrekac
cplusdcine=canalplusdcine-radubrekac
cplusdcinehd=canalplusdcinehd-radubrekac
cplusdep2hd=canalplusdeportes2hd-radubrekac
cplusdeport2=canalplusdeportes2-radubrekac
cplusdeportes=canalplusdeportes-radubrekac
cplusdeporthd=canalplusdeporteshd-radubrekac
cplusestrenos=canalplusestrenos-radubrekac
cplusestrenoshd=canalplusestrenoshd-radubrekac
```
The parts before the `=` sign are the channel's snp names.
The parts after the `=` sign are the logos on **this repository**. Thes are not the channel names.

**Channels with identical names**

When there are different channels but with identical snp names, we distinguish between them by using srp references for some of them. For example there are two different channels on 28.2 but have the same name `sky comedy hd`. The entries in the index to ensure they have linkages to different logos are:

```
EEB_7EE_2_11A0000=skycinemacomedy
skycomedyhd=skycomedy
```

You **cannot** have two different `snp names` that point to different `logos on this repository`. In the example below, only the logo in the topmost line will be used to create a picon.
```
skycomedy=skycomedy
skycomedy=skycinemacomedy
```
