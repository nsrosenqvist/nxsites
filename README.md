NXSites
=======

An utility to easily manage Nginx servers with the functionality of a2ensite and a2dissite for Apache, but for Nginx, including a bunch of extra features.

It is assumed that nginx is configured with the standard sites-available and sites-enabled directory layout and that nginx is controlled via upstart. If you want to implement so that it can work with several init systems then I gladly accept the patches.

## Installation

Clone the repository and then use make.

```bash
git clone https://github.com/nsrosenqvist/nxsites.git && cd nxsites
make && sudo make install
```

## Usage

The first parameter is what action you want to perform. The second parameter is the site name and the third is only used with the `create` action and lets you base your site of a template.

Action                        | Explanation
----------------------------- | ------------------------------------------------------
`<enable>  <site>`            | Enable site
`<disable> <site>`            | Disable site
`<edit>    <site>`            | Edit site
`<create>  <site> [template]` | Create a site - optionally from a pre-defined template
`<delete>  <site>`            | Delete site
`<list>`                      | List sites
`<templates>`                 | List site templates
`<test>`                      | Test nginx config
`<reload>`                    | Reload nginx config
`<restart>`                   | Restart nginx server
`<status>`                    | Show nginx status and site list
`<help>`                      | Display help

## Development

Feel free to make pull requests with your own contributions. If you want to help out and don't know what to do you can try to tackle an issue from the [issue tracker](https://github.com/nsrosenqvist/nxsites/issues).

## Notice

The program is licensed under LGPL v2.1, please refer to the LICENSE file for more information.
