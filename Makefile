SUBDIR=		src
SUBDIR_TARGETS=	upgrade

.include <bsd.subdir.mk>

mnt:
	chflags -R noschg /mnt
	rm -rf /mnt
	mkdir -p /mnt
