# ISSUES

When submitting an issue, make sure you follow these rules:

- Please put entries to `srp.index` or `utf8snp.index` inside fenced code blocks. You can create fenced code blocks by placing a new line with three backticks ` ``` ` before and after the code block. ([READ THIS GUIDE](https://help.github.com/articles/creating-and-highlighting-code-blocks/))
- Logos should be inside an archive, correctly named (see below). Share the link.

Do you like copy/paste? We do too, make sure your issue is easily copy/pasted.

# NAMING

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

__srp.index:__

Contains the partial Enigma2 service references, establishing a link between the actual logos in this repository.
The parts before the `=` sign are the partial service references.
The parts after the `=` sign are the logos on **this repository**. These are not the channel names.

- Only the unique part of the service refernce is used.
For example, Das Erste HD has the following service reference `1_0_19_283D_3FB_1_C00000_0_0_0`

The first three elements are dropped. `1_0_19_`.  Depending on service type, other channels/services could have `1_0_1_` or `1_0_16_` or `4097_0_1_`
The last three elements are dropped too, leaving 

`283D_3FB_1_C00000`

- All entries on the first part must be in UPPERCASE
The logo we want to use on this repository is called `daserstehd`

Example entry in srp.index will be

```
283D_3FB_1_C00000=daserstehd
```


__utf8snp.index:__

Contains utf8 channel names establishing a link between the actual logos in this repository. With the exception of system characters and those listed below, the names will match the channel name. We use lowercase.

The following characters are not allowed:

```
= (equals)
< (less than)
> (greater than)
: (colon)
" (double quote)
/ (forward slash)
\ (backslash)
| (vertical bar or pipe)
? (question mark)
* (asterisk)
```

A full stop at the end of the channel name is not allowed.

Example utf8snp names:

- `Sony Channel +1` => `sony channel +1`
- `BT Sport//ESPN` => `bt sportespn`


# SAMPLES

### srp.index

New additions can go at the top. Best to delete redundant/old entries.

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

New additions can go at the top. Best to delete redundant/old entries, although this is not a requirement.

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

When there are different channels but with identical utf8snp names, we distinguish between them by using srp references for some of them. For example there is `NTV` on a few satellites. They have the same utf8snp name `ntv`. The entries in the index to ensure they have linkages to different logos are:

```
ntv=ntv
55F3_FFDF_36E_1680000=ntv-kiwuslorit
E_64_10_D84AD7F=ntv-stawahicle
1D6F_C3B4_7E_460000=ntv-trahaclasp
D3CD_839_2_11A0000=ntvbangla
```

You **cannot** have two different `utf8snp names` that link to different `logos on this repository`. In the examples below, only the the top line will be used to create a picon.

```
sky comedy=skycomedy
sky comedy=skycinemacomedy
```

```
ntv=ntv
ntv=ntvbangla
```
