PWD          = $(shell pwd)
BUILD_DATE   = $(shell date -u +"%d%m%Y")
RELEASE      = cmsgem
VERSION      = 1.0.0
PACKAGER     = $(shell id --user --name)
PLATFORM     = peta
ARCH         = arm

ifndef BUILD_VERSION
BUILD_VERSION=1
endif

ifndef PACKAGE_VERSION
PACKAGE_VERSION = $(VERSION)
endif

ifndef PACKAGE_RELEASE
PACKAGE_RELEASE = $(BUILD_VERSION).$(RELEASE)
endif

.PHONY: spec_update
spec_update:
	$(info "Executing GEM specific spec_update")
	@mkdir -p ./rpm
	if [ -e ./dummysh.spec.template ]; then \
		echo found dummysh.spec.template; \
		cp ./dummysh.spec.template ./rpm/dummysh.spec; \
        else \
		echo unable to find dummy.spec.template; \
                exit 0; \
	fi

	sed -i 's#__builddate__#$(BUILD_DATE)#'    ./rpm/dummysh.spec
	sed -i 's#__author__#$(PACKAGER)#'         ./rpm/dummysh.spec
	sed -i 's#__release__#$(PACKAGE_RELEASE)#' ./rpm/dummysh.spec
	sed -i 's#__version__#$(PACKAGE_VERSION)#' ./rpm/dummysh.spec
	sed -i 's#__packagedir__#$(PWD)#'          ./rpm/dummysh.spec
	sed -i 's#__platform__#$(PLATFORM)#'       ./rpm/dummysh.spec
	sed -i 's#__buildarch__#$(ARCH)#'          ./rpm/dummysh.spec
	sed -i 's#__arch__#$(ARCH)#'               ./rpm/dummysh.spec

.PHONY: makerpm
makerpm:
	mkdir -p ./rpm/RPMBUILD/{RPMS/$(PLATFORM),SPECS,BUILD,SOURCES,SRPMS}
	rpmbuild  --quiet -ba -bl \
	--define "_binary_payload 1" \
	--define  "_topdir $(PWD)/rpm/RPMBUILD" \
	--target "$(ARCH)" \
	./rpm/dummysh.spec
	find ./rpm/RPMBUILD -name "*.rpm" -exec mv {} ./rpm \;

.PHONY: cleanrpm
cleanrpm:
	-rm -rf ./rpm

.PHONY: rpm
rpm: spec_update makerpm
