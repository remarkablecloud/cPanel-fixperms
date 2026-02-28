#! /bin/bash
# 
# License: GNU General Public License v3.0
# See the Github page for full license and notes:
# https://github.com/PeachFlame/cPanel-fixperms
#

# Set verbose to null
verbose=""

# Print the help text
helptext () {
    tput bold
    tput setaf 2
    echo "Fix Permissions (fixperms) Script help:"
    echo "Sets file/directory permissions to match suPHP and FastCGI schemes"
    echo "USAGE: fixperms [options] -a account_name"
    echo "-------"
    echo "Options:"
    echo "-h or --help: Print this screen and exit"
    echo "--account or -a: Specify a cPanel account"
    echo "-all: Run on all cPanel accounts"
    echo "-v: Verbose output"
    tput sgr0
    exit 0
}

# Main workhorse, fix perms per account passed to it
fixperms () {

    # Get account from what is passed to the function
    account=$1
    
    # Check account against cPanel user files
    if [ ! -f /var/cpanel/users/$account ]; then
        tput bold
        tput setaf 1
        echo "Invalid cPanel account: $account"
        tput sgr0
        return 1
    fi
    
    # Make sure account isn't blank
    if [ -z "$account" ]; then
        tput bold
        tput setaf 1
        echo "Need a cPanel account!"
        tput sgr0
        helptext
    else

        # Get the account's homedir
        HOMEDIR=$(grep "^${account}:" /etc/passwd | cut -d: -f6)

        if [ -z "$HOMEDIR" ]; then
            echo "Could not find home directory for $account"
            return 1
        fi

        tput bold
        tput setaf 4
        echo "(fixperms) for: $account"
        tput setaf 3
        echo "--------------------------"
        tput setaf 4
        echo "Fixing website files in public_html..."
        tput sgr0

        # Fix owner of public_html
        chown $verbose $account:nobody $HOMEDIR/public_html
        
        # Fix individual files and directories in public_html
        find $HOMEDIR/public_html -type d -exec chmod $verbose 755 {} \;
        find $HOMEDIR/public_html -type f ! -name "*.cgi" ! -name "*.pl" -exec chmod $verbose 644 {} \;
        find $HOMEDIR/public_html -name '*.cgi' -o -name '*.pl' | xargs -r chmod $verbose 755
        
        # Hidden files and .htaccess
        # Use a more robust way to handle hidden files to avoid ".." issues
        find $HOMEDIR/public_html -mindepth 1 -name ".*" -exec chown $verbose $account:$account {} \;
        find $HOMEDIR/public_html -name .htaccess -exec chown $verbose $account:$account {} \;
        find $HOMEDIR/public_html -name .htaccess -exec chmod $verbose 644 {} \;

        tput bold
        tput setaf 4
        echo "Fixing public_html itself..."
        tput sgr0
        chmod $verbose 750 $HOMEDIR/public_html

        # --- FIX FOR NEW CPANEL DIRECTORY SCOPE ---
        tput setaf 3
        tput bold
        echo "--------------------------"
        tput setaf 4
        echo "Fixing domains with docroots outside public_html..."
        tput sgr0
        
        # Search recursively (-r) through the userdata directory for 'documentroot'
        # sort -u ensures we don't process the same directory multiple times (e.g. if in both SSL and non-SSL cfg)
        for SUBDOMAIN in $(grep -ri "documentroot" /var/cpanel/userdata/$account/ | grep -v '.cache\|_SSL' | awk '{print $2}' | grep -v public_html | sort -u)
        do
            if [ -d "$SUBDOMAIN" ]; then
                tput bold
                tput setaf 4
                echo "Fixing docroot: $SUBDOMAIN"
                tput sgr0
                chown -R $verbose $account:$account $SUBDOMAIN
                find $SUBDOMAIN -type d -exec chmod $verbose 755 {} \;
                find $SUBDOMAIN -type f ! -name "*.cgi" ! -name "*.pl" -exec chmod $verbose 644 {} \;
                find $SUBDOMAIN -name '*.cgi' -o -name '*.pl' | xargs -r chmod $verbose 755
                chmod $verbose 755 $SUBDOMAIN
                find $SUBDOMAIN -name .htaccess -exec chown $verbose $account:$account {} \;
            fi
        done

        # Finished
        tput bold
        tput setaf 3
        echo "Finished! (User: $account)"
        echo "--------------------------"
        printf "\n"
        tput sgr0
    fi

    return 0
}

# Parses all users via cPanel's users/domains file
all () {
    for user in $(cut -d: -f1 /etc/domainusers | sort -u)
    do
        fixperms "$user"
    done
}

# Main function, switches options passed to it
case "$1" in
    -h|--help) helptext ;;
    -v) 
        verbose="-v"
        case "$2" in
            -all) all ;;
            --account|-a) fixperms "$3" ;;
            *) 
                tput bold; tput setaf 1; echo "Invalid option!"; tput sgr0
                helptext 
            ;;
        esac
    ;;
    -all) all ;;
    --account|-a) fixperms "$2" ;;
    *)
        tput bold; tput setaf 1; echo "Invalid option!"; tput sgr0
        helptext
    ;;
esac
