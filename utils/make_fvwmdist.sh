#!/bin/sh

# options:
#
#  -r   build and commit a release (tags the sources and updates version info)
#
# environment variables:
#
#   FVWMRELNAME
#     The name that will show up in the ChangeLog (only with -r).
#   FVWMRELEMAIL
#     The email address that will show up in the ChangeLog (only with -r).
#   FVWMRELPRECVSCOMMAND
#     A command that will be executed before the first cvs command. Can be used
#     to bring up the network prior to network access. (only with -r)
#   FVWMRELPOSTCVSCOMMAND
#     Same as above, but executed after the last cvs command.

CHECK_FILE=AUTHORS
CHECK_STRING1=fvwm
CHECK_STRING2="Robert Nation"
CHECK_VERSION_STRING="AM_INIT_AUTOMAKE"
VERSION_PRE="fvwm-"
VERSION_POST=".tar.gz"
READY_STRING=" is ready for distribution"

wrong_dir=0

if [ "$1" = -r ] ; then
  IS_RELEASE=1
  echo "Your name and email address will show up in the ChangeLog."
  if [ -z "$FVWMRELNAME" ] ; then
    echo "Please enter your name (set the FVWMRELNAME variable to avoid this)"
    read FVWMRELNAME
  fi
  if [ -z "$FVWMRELEMAIL" ] ; then
    echo "Please enter your name (set the FVWMRELEMAIL variable to avoid this)"
    read FVWMRELEMAIL
  fi
else
  IS_RELEASE=0
fi

err_exit ()
{
  echo
  echo "an error occured while builting the distribution. Error code = $1"
  exit $1
}

if [ ! -r "$CHECK_FILE" ] ; then
  wrong_dir=1
elif ! grep "$CHECK_STRING1" "$CHECK_FILE" ; then
  wrong_dir=1
elif ! grep "$CHECK_STRING2" "$CHECK_FILE" ; then
  wrong_dir=1
fi > /dev/null 2> /dev/null

if [ $wrong_dir = 1 ] ; then
  echo "The fvwm sources are not present in the current directory."
  err_exit 1;
fi

VERSION=`grep $CHECK_VERSION_STRING configure.in 2>&1 |
         cut -f 2 -d "," |
         sed -e "s/[[:space:]]//g" -e "s/)//g"`
VRELEASE=`echo $VERSION | cut -f 1 -d "."`
VMAJOR=`echo $VERSION | cut -f 2 -d "."`
VMINOR=`echo $VERSION | cut -f 3 -d "."`
if [ -z "$VRELEASE" -o -z "$VMAJOR" -o -z "$VMINOR" ] ; then
  echo "Failed to fetch version number from configure.in."
  err_exit 12;
fi
VERSION_STRING=$VERSION_PRE$VRELEASE.$VMAJOR.$VMINOR$VERSION_POST
echo "***** building $VERSION_STRING *****"

# clean up
echo removing old configure files ...
if [ -f configure ] ; then
  rm configure || err_exit 2
fi
if [ -f config.cache ] ; then
  rm config.cache || err_exit 3
fi
if [ -f config.log ] ; then
  rm config.log || err_exit 4
fi
if [ -f config.status ] ; then
  rm config.status || err_exit 5
fi

echo running automake ...
automake --add-missing || err_exit 6
echo running autoreconf ...
autoreconf || err_exit 7
echo running configure ...
./configure --enable-gnome || err_exit 8
echo running make clean ...
make clean || err_exit 9
echo running make ...
make CFLAGS="-g -O2 -Wall -Werror" || err_exit 10
echo running make distcheck2 ...
make distcheck2 2>&1 | grep "$VERSION_STRING$READY_STRING" || err_exit 11
echo
echo "distribution file is ready"
echo
if [ $IS_RELEASE = 0 ] ; then
  echo "If this is to be an official release:"
  echo " . Tag the source tree:"
  echo "     cvs tag version-x_y_z"
  echo " . Increase the version number in configure.in and commit this change"
  echo " . Create entries in ChangeLog and NEWS files indicating the release"
  echo " . Upload the distribution to ftp://ftp.fvwm.org/pub/incoming/fvwm"
  echo " . Notify fvwm-owner@fvwm.org of the upload"
else
  echo updating NEWS file
  NNEWS="new-NEWS"
  perl -pe 's/^(.*) ('$VRELEASE.$VMAJOR.')('$VMINOR') (\(not released yet\))$/$1 $2@{[$3+1]} $4\n\n$1 $2$3 (@{[substr(`date +%Y-%m-%d`,0,10)]})/' \
    < NEWS > $NNEWS || err_exit 12
  mv $NNEWS NEWS || err_exit 13
  echo tagging CVS source
  if [ ! "$FVWMRELPRECVSCOMMAND" = "" ] ; then
    $FVWMRELPRECVSCOMMAND
  fi
  cvs tag version-${VRELEASE}_${VMAJOR}_$VMINOR || err_exit 14
  echo increasing version number in configure.in
  NCFG="new-configure.in"
  touch $NCFG || err_exit 15
  cat configure.in |
  sed -e "s/$VRELEASE\.$VMAJOR\.$VMINOR/$VRELEASE\.$VMAJOR\.$[$VMINOR+1]/g" \
    > $NCFG || err_exit 16
  mv $NCFG configure.in || err_exit 17
  echo generating ChangeLog entry ...
  NCLOG="new-ChangeLog"
  touch $NCLOG || err_exit 18
  echo `date +%Y-%m-%d`"  $FVWMRELNAME  <$FVWMRELEMAIL>" > $NCLOG
  echo >> $NCLOG
  echo "	* NEWS, configure.in:" >> $NCLOG
  echo "	changed version to $VRELEASE.$VMAJOR.$[VMINOR + 1]" >> $NCLOG
  echo >> $NCLOG
  cat ChangeLog >> $NCLOG
  mv $NCLOG ChangeLog || err_exit 19
  echo committing configure.in and ChangeLog
  cvs commit -m \
    "* Set development version to $VRELEASE.$VMAJOR.$[VMINOR + 1]." \
    NEWS configure.in ChangeLog || err_exit 20
  if [ ! "$FVWMRELPOSTCVSCOMMAND" = "" ] ; then
    $FVWMRELPOSTCVSCOMMAND
  fi
  echo
  echo Then
  echo " . Upload the distribution to ftp://ftp.fvwm.org/pub/incoming/fvwm"
  echo " . Notify fvwm-owner@fvwm.org of the upload"
  echo " . Update the version numbers in fvwm-web/download.html"
fi
