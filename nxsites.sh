#!/bin/bash

#-----------------------------------------------------------------------------------#
# An utility to easily manage Nginx servers with the functionality of
# a2ensite and a2dissite for Apache, but for Nginx, including a bunch of extra features.
# Copyright (C) 2014 Niklas Rosenqvist
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#-----------------------------------------------------------------------------------#

NGINX_CONF_FILE="$(awk -F= -v RS=' ' '/conf-path/ {print $2}' <<< $(nginx -V 2>&1))"
NGINX_CONF_DIR="$(cd "$(dirname "$NGINX_CONF_FILE")" && pwd)"
NGINX_TEMPL_DIR="$NGINX_CONF_DIR/templates.d/"
SELECTED_SITE="$2"
VERSION="v1.1.1"

#/ Echo error message #/
function error() {
    echo -e "\033[1;31mError! $@\033[m" 1>&2
    return $?
}

#/ Enable the specified site if it exists #/
function enable_site() {
    if [ -z "$SELECTED_SITE" ]; then
        error "You must specify a site"
        return 1
    fi

    if [ -f "$NGINX_CONF_DIR/sites-available/$SELECTED_SITE" ]; then
        if [ -h "$NGINX_CONF_DIR/sites-enabled/$SELECTED_SITE" ]; then
            echo "$SELECTED_SITE is already enabled"
            return 0
        else
            ln -s "$NGINX_CONF_DIR/sites-available/$SELECTED_SITE" "$NGINX_CONF_DIR/sites-enabled/$SELECTED_SITE"

            if [ $? -eq 0 ]; then
                echo "$SELECTED_SITE enabled"
                return 0
            else
                error "Failed to enabled $SELECTED_SITE"
                return 1
            fi
        fi
    else
        error "$SELECTED_SITE isn't defined"
        return 1
    fi
}

#/ Disable the specified site if it exists #/
function disable_site() {
    if [ -z "$SELECTED_SITE" ]; then
        error "You must specify a site"
        return 1
    fi

    if [ -f "$NGINX_CONF_DIR/sites-available/$SELECTED_SITE" ]; then
        if [ ! -h "$NGINX_CONF_DIR/sites-enabled/$SELECTED_SITE" ]; then
            echo "$SELECTED_SITE is already disabled"
            return 0
        else
            rm -f "$NGINX_CONF_DIR/sites-enabled/$SELECTED_SITE"

            if [ $? -eq 0 ]; then
                echo "$SELECTED_SITE disabled"
                return 0
            else
                error "Failed to disable $SELECTED_SITE"
                return 1
            fi
        fi
    else
        error "$SELECTED_SITE isn't defined"
        return 1
    fi
}

#/
# Create a new site - optionally from a template
#
# The templates to choose from are the ones located in $NGINX_TEMPL_DIR.
# If a template is specified then it get's copied to sites-available directory.
#
# @param int $1 The template to base the site configuration on
#/
function create_site() {
    local template=""

    if [ -n "$1" ]; then
        template="$1"
    fi

    if [ -z "$SELECTED_SITE" ]; then
        error "You must specify a site"
        return 1
    fi

    if [ ! -f "$NGINX_CONF_DIR/sites-available/$SELECTED_SITE" ]; then
        if [ -n "$template" ]; then
            if [ -f "$NGINX_TEMPL_DIR/$template" ]; then
                cp "$NGINX_TEMPL_DIR/$template" "$NGINX_CONF_DIR/sites-available/$SELECTED_SITE"
            else
                error "The template \"$template\" isn't defined"
                return 1
            fi
        fi

        editor "$NGINX_CONF_DIR/sites-available/$SELECTED_SITE"
        return 0
    else
        error "$SELECTED_SITE already exists"
        return 1
    fi
}

#/ Launches a editor instance with the specified file #/
function edit_site() {
    if [ -z "$SELECTED_SITE" ]; then
        error "You must specify a site"
        return 1
    fi

    if [ -f "$NGINX_CONF_DIR/sites-available/$SELECTED_SITE" ]; then
        editor "$NGINX_CONF_DIR/sites-available/$SELECTED_SITE"
        return $?
    else
        error "$SELECTED_SITE isn't defined"
        return 1
    fi
}

#/ Deletes the selected site after the user's confirmation #/
function delete_site() {
    if [ -z "$SELECTED_SITE" ]; then
        error "You must specify a site"
        return 1
    fi

    if [ -f "$NGINX_CONF_DIR/sites-available/$SELECTED_SITE" ]; then
        echo -n "Are you sure you want to delete $SELECTED_SITE? (y/n) " && read -n 1 reply

        case $reply in
            [Yy]*)
                if [ -h "$NGINX_CONF_DIR/sites-enabled/$SELECTED_SITE" ]; then
                    rm -f "$NGINX_CONF_DIR/sites-enabled/$SELECTED_SITE"
                fi

                rm -f "$NGINX_CONF_DIR/sites-available/$SELECTED_SITE"
                local result=$?

                if [ $result -eq 0 ]; then
                    echo -e "\n$SELECTED_SITE successfully deleted"
                else
                    echo ""
                    error "Failed to delete $SELECTED_SITE"
                fi

                return $result
            ;;
            * )
                echo -e "\nAborted!"
                return 0
            ;;
        esac
    else
        error "$SELECTED_SITE isn't defined"
        return 1
    fi
}

#/ Prints out a detailed site list with information about state and modification time #/
function list_sites() {
    local maxsitelen=0
    local sites=()
    local moddate=""
    local sitestate=""
    local enableddate=""

    while IFS= read -r file; do
        sites+=("$(basename "$file")")
    done < <(find "$NGINX_CONF_DIR/sites-available/" -maxdepth 1 -type f | sort -V)

    for i in "${sites[@]}"; do
        take_if_higher $maxsitelen ${#i} "maxsitelen"
    done

    maxsitelen=$(($maxsitelen+4))

    echo ""
    echo -n "$(pad_string "Site:" $maxsitelen)"
    echo -n "$(pad_string "State:" 12)"
    echo -n "$(pad_string "Enabled:" 23)"
    echo "$(pad_string "Modified:" 23)"

    for i in "${sites[@]}"; do
        # Site name
        echo -n "$(pad_string "$i" $maxsitelen)"

        # Site status
        if [ -h "$NGINX_CONF_DIR/sites-enabled/$i" ]; then
            sitestate="enabled"
        else
            sitestate="disabled"
        fi

        echo -n "$(pad_string "$sitestate" 12)"

        # Site enabled date
        if [ "$sitestate" = "enabled" ]; then
            enableddate="$(stat -c "%y" "$NGINX_CONF_DIR/sites-enabled/$i")"
            enableddate="${enableddate%%.*}"
        else
            enableddate=""
        fi

        echo -n "$(pad_string "$enableddate" 23)"

        # Modification date
        moddate="$(stat -c "%y" "$NGINX_CONF_DIR/sites-available/$i")"
        moddate="${moddate%%.*}"
        echo "$(pad_string "$moddate" 23)"
    done

    echo ""
    return 0
}

#/ Reload the nginx config #/
function list_templates() {
    local templates=()

    while IFS= read -r file; do
        templates+=("$(basename "$file")")
    done < <(find "$NGINX_TEMPL_DIR" -maxdepth 1 -type f | sort -V)

    if [ ! ${#templates[@]} -gt 0 ]; then
        echo "No templates are defined in \"$NGINX_TEMPL_DIR\""
    else
        echo -e "\nTemplates:"
        for i in "${templates[@]}"; do
            echo "$i"
        done
        echo ""
    fi

    return 0
}

#/ Reload the nginx config #/
function reload_config() {
    service nginx reload
    return $?
}

#/ Test the nginx config #/
function test_config() {
    nginx -t
    return $?
}

#/ Restarts the nginx server #/
function restart_server() {
    service nginx restart
    return $?
}

#/ Prints out the nginx server status plus the site list #/
function status() {
    echo ""
    service nginx status
    list_sites
    return 0
}

#/ Pads string so that tables are properly formatted #/
function pad_string() {
    printf "%-${2}s" "$1"
}

#/
# Used to find out the longest table cell
#
# To get properly formatted tables, where all the cells are aligned,
# we have to find out what the maximum length is. We do that by passing
# both the old and new value to compare with and sets provided variable
# by using eval. That way we can loop easily and find it quickly.
#
# @param int $1 The currently highest value
# @param int $2 The new value to compare with
# @param string $3 The name of the variable to set, we use the variable
#                  name of the one we provide for $1.
#/
function take_if_higher() {
    local oldval=$1
    local newval=$2
    local saveto="$3"

    if [ $newval -gt $oldval ]; then
        eval "$saveto=$2"
    fi
}

#/ Prints out a message about the applications usage #/
help_msg() {
    echo -e "\nNXSites $VERSION - Usage: ${0##*/} [options]"
    echo "Options:"
    echo -e "\t$(pad_string "<enable>  <site>" 30) Enable site"
    echo -e "\t$(pad_string "<disable> <site>" 30) Disable site"
    echo -e "\t$(pad_string "<edit>    <site>" 30) Edit site"
    echo -e "\t$(pad_string "<create>  <site> [template]" 30) Create a site - optionally from a pre-defined template"
    echo -e "\t$(pad_string "<delete>  <site>" 30) Delete site"
    echo -e "\t$(pad_string "<list>" 30) List sites"
    echo -e "\t$(pad_string "<templates>" 30) List site templates"
    echo -e "\t$(pad_string "<test>" 30) Test nginx config"
    echo -e "\t$(pad_string "<reload>" 30) Reload nginx config"
    echo -e "\t$(pad_string "<restart>" 30) Restart nginx server"
    echo -e "\t$(pad_string "<status>" 30) Show nginx status and site list"
    echo -e "\t$(pad_string "<version>" 30) Show nxsites version"
    echo -e "\t$(pad_string "<help>" 30) Display help"
    echo -e "\n\tIt is assumed you are using the default sites-enabled and sites-available configuration.\n"
    return 0
}

# Verify that nginx is installed
dpkg -s "nginx" >/dev/null 2>&1

if [ $? -eq 0 ]; then
    # Create a templates.d directory in the Nginx config directory if it doesn't exist
    if [ ! -e "$NGINX_TEMPL_DIR" ]; then
        mkdir "$NGINX_TEMPL_DIR"
    fi
else
    error "Nginx is not installed"
    exit 1
fi

# Main
case "$1" in
    enable) enable_site;;
    disable) disable_site;;
    edit) edit_site;;
    create) create_site "$3";;
    delete) delete_site;;
    list|-l|--list) list_sites;;
    templates) list_templates;;
    test) test_config;;
    reload) reload_config;;
    restart) restart_server;;
    status) status;;
    version|-v|--version) echo "$VERSION";;
    help|-h|--help) help_msg;;
    *)
        echo -e "\nNo options selected"
        help_msg
        exit 1
    ;;
esac

exit $?
