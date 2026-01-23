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
- The `logo_name` to be used to create the picons.


# Logos

Do the logos you want to be used to create the picons exist in this repository?

If they do, please use the correct and existing names.

If they not exist and you are adding new logos, please name them properly like the other logos in the `logo` directory of this repository.
Create a `zip` with the new logos and attach them to your issue. You can drag and drop to attach the zip file to your issue.

If you are just updating the existing logos and there are no changes to service references, please use the exact names that we already have, so we can overwrite existing logos.

```
logos.zip
```


# SRP or UTF8SNP entries

**utf8snp.index**
```
utf8snpname=logo_name
utf8snpname1=logo_name1
utf8snpname2=logo_name2
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
