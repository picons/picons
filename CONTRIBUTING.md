# ISSUES

When submitting an issue, make sure you follow these rules:

- Please put entries to `srp.index` or `utf8snp.index` inside fenced code blocks. You can create fenced code blocks by placing a new line with three backticks ` ``` ` before and after the code block. ([Read this guide](https://help.github.com/articles/creating-and-highlighting-code-blocks/))
- Logos should be inside an archive, correctly named (see below). Share the link.

Do you like copy/paste? We do too — make sure your issue is easily copy/pasted.

# NAMING

**Logo:**

- Lowercase only.
- No spaces, fancy symbols or `.-+_*`, except for the exceptions below.
- Time sharing channels are separated by `_`.
- If the logo name you wish to use already exists, add a unique identifier like `-trechuhipe` (a pronounceable random 10-character string, generated using [this](http://www.generate-password.com) password generator). Grouping logos together using the same unique identifier is allowed.
- Preferred filetype is `svg`; use `png` only as a fallback.
- Resolution doesn't matter for `svg`; for `png`, aim for > 800px.
- When submitting `svg` files, convert all text to paths.
- `svg` files must not contain base64-encoded images.
- `svg` files must be rsvg-compatible and open correctly in Inkscape (Adobe Illustrator-only compatibility is not acceptable).
- If your `png` can be easily traced with Inkscape, submit only the `svg`.
- Quality should be as high as possible.
- Background must be transparent.
- No empty space around the logo.
- A `default` version of a logo gets the suffix `.default` in the filename. Additional variants use `.light`, `.dark`, `.black`, or `.white`.

Logo type reference:

```
default  — standard logo as used by the TV station; looks good on the background intended by the station (mostly white)
light    — modified default with darker parts made lighter; looks good on dark backgrounds
dark     — modified default with lighter parts made darker; looks good on light backgrounds
white    — fully white, no colors (indexed 1-bit, black/white); looks good on dark backgrounds
black    — fully black, no colors (indexed 1-bit, black/white); looks good on light backgrounds
```

---

**srp.index:**

Contains the `partial Enigma2 service references` that link the channels to logos in this repository.

- The part before `=` is the partial service reference (uppercase only).
- The part after `=` is the logo name in this repository (not the channel name).

Only the unique part of the service reference is used. For example, Das Erste HD has the full service reference `1_0_19_283D_3FB_1_C00000_0_0_0`. The first three elements (`1_0_19_`) and the last three elements are dropped, leaving:

```
283D_3FB_1_C00000
```

Depending on service type, the dropped prefix could also be `1_0_1_`, `1_0_16_`, or `4097_0_1_`.

The logo for Das Erste HD in this repository is called `daserstehd`, so the entry is:

```
283D_3FB_1_C00000=daserstehd
```

---

**utf8snp.index:**

Contains `UTF-8 channel names` that link the channels to logos in this repository. With the exception of system characters and those listed below, names match the channel name and are lowercase.

The following characters are not allowed:

```
<   (less than)
>   (greater than)
:   (colon)
"   (double quote)
/   (forward slash)
\   (backslash)
|   (vertical bar or pipe)
?   (question mark)
*   (asterisk)
```

A full stop at the end of a channel name is also not allowed.

Examples:

- `Sony Channel +1` → `sony channel +1`
- `BT Sport//ESPN` → `bt sportespn`
- `a.tv HD .` → `a.tv hd`


**Channels with identical names:**

When different channels share the same utf8snp name, use srp references to distinguish them. For example, several satellites carry a channel called `NTV`, all sharing the utf8snp name `ntv`. The entries to ensure each links to a different logo are:

```
ntv=ntv
55F3_FFDF_36E_1680000=ntv-kiwuslorit
E_64_10_D84AD7F=ntv-stawahicle
1D6F_C3B4_7E_460000=ntv-trahaclasp
D3CD_839_2_11A0000=ntvbangla
```

**Important:** you cannot have two identical utf8snp names that map to two different logos. Pull requests with multiple assignments will fail.  An example of a double assignemnt is below

```
sky comedy=skycomedy
sky comedy=skycinemacomedy
```


# SAMPLES

### srp.index

New additions can go at the top. Deleting redundant or outdated entries is encouraged but not required.

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

New additions can go at the top. Deleting redundant or outdated entries is encouraged but not required.

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
