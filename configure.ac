dnl init
dnl AC_REVISION($Revision: 1.30 $)
AC_PREREQ([2.69])
dnl Version follows Semantic Versioning 2.0.0; the single source of truth is ./VERSION
AC_INIT([chan_dongle],[m4_esyscmd_s([cat VERSION])],[https://github.com/KernelPanicNT/asterisk-chan-dongle/issues],[chan_dongle],[https://github.com/KernelPanicNT/asterisk-chan-dongle/])
dnl Revision: "git describe" when building from a checkout, "release" otherwise.
PACKAGE_REVISION=`(cd "$srcdir" && git describe --always --dirty --abbrev=8) 2>/dev/null || echo release`
AC_CANONICAL_TARGET
AM_INIT_AUTOMAKE
AC_CONFIG_HEADERS([config.h])
AC_CONFIG_SRCDIR([chan_dongle.c])
AC_CONFIG_FILES([stamp-h], [echo timestamp > stamp-h])
AC_CANONICAL_HOST

dnl AM_INIT_AUTOMAKE

CPPFLAGS="$CPPFLAGS -D_GNU_SOURCE"

dnl Checks for user settings.
dnl  Set asterisk headers patch
AC_ARG_WITH(
	[asterisk],
	AS_HELP_STRING([--with-asterisk=path], [set asterisk headers location]),
	[ if test "x$with_asterisk" = "xyes" -o "x$with_asterisk" = "xno" ; then  AC_MSG_ERROR([Invalid --with-asterisk=path value]); fi ],
	[ with_asterisk="../include /usr/include /usr/local/include /opt/local/include" ]
)
dnl  Set iconv headers patch
AC_ARG_WITH(
	[iconv],
	AS_HELP_STRING([--with-iconv=path], [set iconv headers location]),
	[ if test "x$with_iconv" = "xyes" -o "x$with_iconv" = "xno" ; then  AC_MSG_ERROR([Invalid --with-iconv=path value]); fi ],
	[ with_iconv="../include /usr/include /usr/local/include /opt/local/include" ]
)

dnl  Asterisk version: --with-astversion=M.m.u, or auto-detected from
dnl  pkg-config (asterisk.pc) or from the output of "asterisk -V".
AC_ARG_WITH(
	[astversion],
	AS_HELP_STRING([--with-astversion=M.m.u], [set asterisk version; for example: 22 or 24.0.0 (default: auto-detect)]),
	[],
	[ with_astversion=auto ]
)
if test "x$with_astversion" = "xauto" -o "x$with_astversion" = "xyes" ; then
	AC_MSG_CHECKING([for installed asterisk version])
	with_astversion=`pkg-config --modversion asterisk 2>/dev/null | sed -e 's/[[^0-9.]].*//'`
	if test -z "$with_astversion" ; then
		for astbin in asterisk /usr/sbin/asterisk /usr/local/sbin/asterisk ; do
			with_astversion=`$astbin -V 2>/dev/null | sed -n -e 's/^Asterisk \([[0-9]][[0-9.]]*\).*/\1/p'`
			test -n "$with_astversion" && break
		done
	fi
	if test -z "$with_astversion" ; then
		AC_MSG_RESULT([not found])
		AC_MSG_ERROR([Cannot detect the asterisk version, please set --with-astversion=M.m.u (major.minor.micro)])
	fi
	AC_MSG_RESULT([$with_astversion])
fi
if echo "$with_astversion" | grep -qE '^[[0-9]][[0-9]]?(\.[[0-9]][[0-9]]?){0,2}$'
then with_astversion=$(echo $with_astversion | sed -e 's/.*/&.0.0/' | tr . '\n' |
		 head -n3 | sed -e 's/^.$/0&/' | tr -d '\n' | sed -e 's/^0*//')
else AC_MSG_ERROR([Invalid --with-astversion=M.m.u value: $with_astversion]); fi
if test "$with_astversion" -lt 200000 ; then
	AC_MSG_WARN([Asterisk older than 20 is not tested by this fork; tested: 20, 22, 24 (LTS)])
fi
AC_DEFINE_UNQUOTED([ASTERISK_VERSION_NUM], [$with_astversion],
		   [The Asterisk version as configured --with-astversion.])

AC_ARG_ENABLE(
	[debug],
	AS_HELP_STRING([--enable-debug], [enable code debugging]),
	[ if test "x$enable_debug" != "xyes" ; then enable_debug="no" ; fi],
	[ enable_debug="no"]
)

AC_ARG_ENABLE(
	[warnings-as-errors],
	AS_HELP_STRING([--enable-warnings-as-errors], [abort compilation on errors]),
	[ if test "x$enable_warnings_as_errors" != "xyes" ; then enable_warnings_as_errors="no" ; fi],
	[ enable_warnings_as_errors="no"]
)

dnl  Optionally disable manager.
AC_ARG_ENABLE(
	[manager],
	AS_HELP_STRING([--enable-manager], [enable manager code]),
	[ if test "x$enable_manager" != "xyes" ; then enable_manager="no" ; fi ],
	[ enable_manager="yes" ]
)

dnl  Optionally disable applications
AC_ARG_ENABLE(
	[apps],
	AS_HELP_STRING([--enable-apps], [enable applications code]),
	[ if test "x$enable_apps" != "xyes" ; then enable_apps="no" ; fi],
	[ enable_apps="yes" ]
)

dnl Checks for programs.
AC_PROG_CC([gcc cl cc])
AC_PROG_CPP
AC_PROG_INSTALL

AC_CHECK_PROG(STRIP,strip,strip)
if test -z "$STRIP" ; then
    AC_MSG_ERROR([Can't find strip])
fi
AC_CHECK_PROG(RM,rm,rm)
if test -z "$RM" ; then
    AC_MSG_ERROR([Can't find rm])
fi

dnl Checks for libraries.
dnl AC_CHECK_LIB([pthread], [pthread_create])  # should use ast_pthread_join everywhere?
AC_SEARCH_LIBS([iconv], [c iconv],,AC_MSG_ERROR([iconv library missing]))
AC_CHECK_LIB([sqlite3], [sqlite3_open],,AC_MSG_ERROR([sqlite3 library missing]))

dnl Checks for header files.
AC_CHECK_HEADERS([fcntl.h stdlib.h string.h sys/time.h termios.h])
AC_DEFUN([AC_HEADER_FIND], [
    file=$1
    found=no
    for path in $2 ; do
	AC_MSG_CHECKING([whether $file in $path])
	if test -f $path/$file ; then
	    found="yes"
	    CPPFLAGS="$CPPFLAGS -I${path}"
	    AC_MSG_RESULT([yes])
	    AC_CHECK_HEADER([$file])
	    break;
	fi
	AC_MSG_RESULT([no])
    done
    if test "$found" = "no"; then
	AC_MSG_ERROR([Can't find "$file"])
    fi
    ]
)

AC_HEADER_FIND([asterisk.h], $with_asterisk)
AC_HEADER_FIND([iconv.h], $with_iconv)
AC_CHECK_HEADER([sqlite3.h],,AC_MSG_ERROR([sqlite3.h header file missing]))

AC_DEFINE([ICONV_CONST],[], [Define to const if you has iconv() const declaration of input buffer])
AC_MSG_CHECKING([for iconv use const inbuf])
AC_EGREP_HEADER([^extern.+iconv[[:space:]]*\(.+const], [iconv.h],
    [
    AC_DEFINE([ICONV_CONST],[const])
    AC_MSG_RESULT([yes])
    ],
    [AC_MSG_RESULT([no])]
)

AC_MSG_CHECKING([for iconv_t in iconv.h])
AC_EGREP_HEADER([iconv_t], [iconv.h],
    [
    AC_DEFINE([ICONV_T], [iconv_t], , [Define to iconv_t if you has iconv_t in iconv.h])
    AC_MSG_RESULT(yes)
    ],
    [

    AC_DEFINE([ICONV_T], [int], [Define to iconv_t if you has iconv_t in iconv.h])
    AC_MSG_RESULT(no)
    ])

AC_MSG_CHECKING([for AST_CONTROL_SRCCHANGE in asterisk/frame.h])
AC_EGREP_HEADER([AST_CONTROL_SRCCHANGE], [asterisk/frame.h],
    [
    AC_DEFINE([HAVE_AST_CONTROL_SRCCHANGE], [], [Define to 1 if you have HAVE_AST_CONTROL_SRCCHANGE in asterisk/frame.h])
    AC_MSG_RESULT([yes])
    ],
    [AC_MSG_RESULT([no])]
)


dnl Checking for library options

dnl Checks for typedefs, structures, and compiler characteristics.
AC_C_CONST
AC_C_INLINE
AC_TYPE_SIZE_T
AC_TYPE_SSIZE_T
AC_TYPE_UINT64_T
dnl AC_CHECK_TYPE(size_t, unsigned long)
dnl AC_CHECK_TYPE(ssize_t, long)
dnl AC_CHECK_TYPE(uint64_t, unsigned long long)

AC_CHECK_SIZEOF(int)
AC_CHECK_SIZEOF(long int)
AC_CHECK_SIZEOF(long long int)
AC_CHECK_SIZEOF(time_t)
case "$ac_cv_sizeof_time_t" in
''|0) AC_MSG_ERROR([Could not find time_t type]);;
$ac_cv_sizeof_int) AC_DEFINE([PRI_time_t], ["d"], [printf format for time_t]);;
$ac_cv_sizeof_long_int) AC_DEFINE([PRI_time_t], ["ld"], [printf format for time_t]);;
$ac_cv_sizeof_long_long_int) AC_DEFINE([PRI_time_t], ["lld"], [printf format for time_t]);;
*) AC_MSG_ERROR([Could not find match size of time_t to printf format])
esac

dnl checking compiler options
AC_DEFUN([AC_CC_OPT], [
    my_save_cflags="$CFLAGS"
    CFLAGS="$1"
    AC_MSG_CHECKING([whether CC supports $1])
    AC_COMPILE_IFELSE([AC_LANG_PROGRAM([])],
    [AC_MSG_RESULT([yes])]
    [AC_CFLAGS="$AC_CFLAGS $2"],
    [AC_MSG_RESULT([no])]
    )
    CFLAGS="$my_save_cflags"]
    )

AC_CFLAGS=

my_save_cflags="$CFLAGS"
CFLAGS=-fvisibility=hidden
AC_MSG_CHECKING([whether CC supports -fvisibility=hidden])
AC_COMPILE_IFELSE([AC_LANG_PROGRAM([])],
    [AC_MSG_RESULT([yes])]
    [TARGET="chan_dongle.so"]
    [AC_CFLAGS="$AC_CFLAGS -fvisibility=hidden"],
    [AC_MSG_RESULT([no])]
    [TARGET="chan_dongles.so"]
    )
CFLAGS="$my_save_cflags"
AC_SUBST([TARGET])

AC_CC_OPT([-fPIC],[-fPIC])
AC_CC_OPT([-Wall],[-Wall])
AC_CC_OPT([-Wextra],[-Wextra])
if test "x$enable_warnings_as_errors" = "xyes" ; then
    AC_CC_OPT([-Werror=all],[-Werror=all])
    AC_CC_OPT([-Werror=extra],[-Werror=extra])
    AC_CC_OPT([-Werror=discarded-qualifiers],[-Werror=discarded-qualifiers])
    AC_CC_OPT([-Wno-error=format-truncation],[-Wno-error=format-truncation])
fi
AC_CC_OPT([-MD -MT conftest.o -MF /dev/null -MP],[-MD -MT \$@ -MF .\$(subst /,_,\$@).d -MP])

AC_DEFUN([AC_CHECK_DESTDIR], [
    if test -z "$DESTDIR" ; then
	found=no
	for path in $1 ; do
	    AC_MSG_CHECKING([whether DESTDIR is $path])
	    if test -f $path/pbx_config.so ; then
		AC_MSG_RESULT([yes])
		found="yes"
		DESTDIR=$path
		break;
	    fi
	    AC_MSG_RESULT([no])
	done
	if test "$found" = "no"; then
	    AC_MSG_ERROR([DESTDIR is unknown, please be explicit: ./configure DESTDIR=/usr/lib/asterisk/modules])
	fi
    fi
    ])

dnl This detection is kind of flaky. Don't rely on it. The module
dnl directory could be lib64 or x86_64-linux-gnu or even somewhere
dnl completely custom.
dnl Prefer the astmoddir configured in asterisk.conf (FreePBX, Debian multiarch).
if test -z "$DESTDIR" ; then
    for astconf in /etc/asterisk/asterisk.conf /usr/local/etc/asterisk/asterisk.conf ; do
	test -f "$astconf" || continue
	astmoddir=`sed -n -e 's/^[[[:space:]]]*astmoddir[[[:space:]]]*=>*[[[:space:]]]*\([[^[:space:];]]*\).*/\1/p' "$astconf" | head -n1`
	if test -n "$astmoddir" && test -f "$astmoddir/pbx_config.so" ; then
	    AC_MSG_NOTICE([using astmoddir from $astconf: $astmoddir])
	    DESTDIR=$astmoddir
	    break
	fi
    done
fi
AC_CHECK_DESTDIR([ \
    /usr/lib/asterisk/modules /usr/lib64/asterisk/modules \
    /usr/lib/x86_64-linux-gnu/asterisk/modules /usr/lib/aarch64-linux-gnu/asterisk/modules \
    /lib/x86_64-linux-gnu/asterisk/modules /lib/aarch64-linux-gnu/asterisk/modules \
    /usr/local/lib/asterisk/modules /opt/local/lib/asterisk/modules])

dnl Checks for library functions.
AC_FUNC_MEMCMP
AC_CHECK_FUNCS([memchr memmove memset memmem strcasecmp strchr strncasecmp strtol realpath])


dnl Apply options to defines
if test "x$enable_debug" = "xyes" ; then
  CFLAGS="$CFLAGS -O0 -g3"
  AC_DEFINE([__DEBUG__], [1], [Build with debugging])
else
  CFLAGS="$CFLAGS -O2"
fi

dnl Asterisk header files use lots of old style declarations, ignore those.
dnl > warning: ‘inline’ is not at beginning of declaration [-Wold-style-declaration]
dnl >   static void force_inline _ast_assert(...)
CFLAGS="$CFLAGS -Wno-old-style-declaration"

if test "x$enable_manager" = "xyes" ; then
  AC_DEFINE([BUILD_MANAGER],[1], [Build Manager extensions])
fi

if test "x$enable_apps" = "xyes" ; then
  AC_DEFINE([BUILD_APPLICATIONS],[1],[Build Application extensions])
fi

case "$target_os" in
    linux*)
	SOLINK="-shared -Xlinker -x"
	DC_LDFLAGS=""
	;;
    freebsd*)
	SOLINK="-shared -Xlinker -x"
	DC_LDFLAGS="-L/usr/local/lib"
	;;
    openbsd*)
	SOLINK="-shared -Xlinker -x"
	DC_LDFLAGS="-L/usr/local/lib -pthread"
	AC_CFLAGS="$AC_CFLAGS -pthread"
	;;
    darwin*)
	SOLINK="-dynamic -bundle -Xlinker -macosx_version_min -Xlinker 10.4 -Xlinker -undefined -Xlinker dynamic_lookup -force_flat_namespace"
	DC_LDFLAGS="-L/opt/local/lib"
	[ `/usr/bin/sw_vers -productVersion | cut -c1-4` == "10.6" ] && SOLINK="$SOLINK /usr/lib/bundle1.o"
esac

LDFLAGS="$LDFLAGS $DC_LDFLAGS"

dnl AC_DEFINE_UNQUOTED([MODULE_], "$PACKAGE_", [])
dnl AC_DEFINE_UNQUOTED([MODULE_], "$PACKAGE_", [])
AC_DEFINE_UNQUOTED([MODULE_BUGREPORT], "$PACKAGE_BUGREPORT", [Define to the address where bug reports for this package should be sent])
AC_DEFINE_UNQUOTED([MODULE_URL], "$PACKAGE_URL", [Define to the home page for this package])
AC_DEFINE_UNQUOTED([MODULE_VERSION], "$PACKAGE_VERSION", [Define to the version of this package])
AC_DEFINE_UNQUOTED([AST_MODULE],"$PACKAGE_NAME",[name of asterisk module])
AC_DEFINE_UNQUOTED([PACKAGE_REVISION], "$PACKAGE_REVISION",[Revision of package])

AC_SUBST([SOLINK])
AC_SUBST([PACKAGE_TARNAME])
AC_SUBST([PACKAGE_REVISION])
AC_SUBST([PACKAGE_VERSION])
AC_SUBST([DESTDIR])
AC_SUBST([AC_CFLAGS])
AC_CONFIG_FILES([Makefile])
AC_OUTPUT
