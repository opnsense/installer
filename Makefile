SUBDIR=		src
SUBDIR_TARGETS=	upgrade

.include <bsd.subdir.mk>

mnt:
	if mount | awk '{ print $$3 }' | grep -q ^/mnt/dev'$$'; then umount /mnt/dev; fi
	chflags -R noschg /mnt
	rm -rf /mnt
	mkdir -p /mnt
