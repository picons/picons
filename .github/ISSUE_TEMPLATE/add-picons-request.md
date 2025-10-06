---
name: Update request
about: This template helps you make a proper request to update logos or *.index entries
title: A description of what you are updating by this request
labels: update
assignees: ''

---

# Details you will need

- Name of the channel as you see it on the receiver.
- Full Service reference of the channel. You can get this from openwebif.
- `Partial service reference` as used in this project. 
- `utf8snp name` of the channel if you are adding to utf8snp.index
- `snpname` of the channel if you are adding to snp.index
- The `logo_name` to be used to create the picons.


# Logos

Do the logo's you want to be used to create the picon exits in this repository?

If not, name them in the properly like other logos in the `logo` directory of this repository.
Create a `zip` with the new logos and attach them to your issue. You can drag and drop it.

```
logos.zip
```


# SNP/SRP/UTF8SNP entries

**utf8snp.index**
```
utf8snpname=logo_name
utf8snpname1=logo_name1
utf8snpname2=logo_name2
```

**snp.index**
```
snpname=logo_name
snpname1=logo_name
snpname2=logo_name
```

**srp.index**
```
422B_3DB8_13E_820000=logo_name
425A_3DB8_13E_820000=logo_name1
4257_3DB8_13E_820000=logo_name2
```

_Make sure you replace the above sample data with the actual data you want added._

_If you can, it is be better to submit a pull request._


**PS: Make sure to read [CONTRIBUTING.md](https://github.com/picons/picons/blob/master/CONTRIBUTING.md)**
