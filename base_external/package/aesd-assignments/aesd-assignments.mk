# Note: Every variable must start with AESD_ASSIGNMENTS_
AESD_ASSIGNMENTS_VERSION = 'head'
AESD_ASSIGNMENTS_SITE = $(TOPDIR)/../finder-app
AESD_ASSIGNMENTS_SITE_METHOD = local

define AESD_ASSIGNMENTS_BUILD_CMDS
	$(MAKE) $(TARGET_CONFIGURE_OPTS) -C $(@D) all
endef

define AESD_ASSIGNMENTS_INSTALL_TARGET_CMDS
	# Install binaries to /usr/bin
	$(INSTALL) -m 0755 $(@D)/writer $(TARGET_DIR)/usr/bin/
	$(INSTALL) -m 0755 $(@D)/finder.sh $(TARGET_DIR)/usr/bin/
	$(INSTALL) -m 0755 $(@D)/finder-test.sh $(TARGET_DIR)/usr/bin/

	# Install config files to /etc/finder-app/conf/
	$(INSTALL) -d 0755 $(TARGET_DIR)/etc/finder-app/conf/
	$(INSTALL) -m 0644 $(TOPDIR)/../conf/assignment.txt $(TARGET_DIR)/etc/finder-app/conf/
	$(INSTALL) -m 0644 $(TOPDIR)/../conf/username.txt $(TARGET_DIR)/etc/finder-app/conf/
endef

$(eval $(generic-package))



