#!/bin/bash -eE

# Allow ** globs
shopt -s globstar

# Copy fd1 and fd2 for reset in trap
exec 3>&1 4>&2

## @file
## @author CMS GEM DAQ Project
## @ingroup LegacyReleasing
## @copyright MIT
## @version 1.0
## @brief Script to facilitate creation and deployment of legacy GEM software releases.


## @defgroup LegacyReleasing Legacy SW Release
## @brief Use this module to create a legacy software release.
## @details This module contains related to creating a GEM DAQ
##          various functions to facilitate creating a software
##          release for legacy tooling.
##
## @par Usage @c make_legacy_release.sh @c -h
##
##      The main entry point is provided in the function @ref make_legacy_release.


## @var EOS_SITE_NAME
## @brief Name of EOS hosted website
## @ingroup LegacyReleasing
declare -rx EOS_SITE_NAME=cmsgemdaq

## @var EOS_SITE_URL
## @brief URL of EOS hosted website
## @ingroup LegacyReleasing
declare -rx EOS_SITE_URL=https://${EOS_SITE_NAME}.web.cern.ch/${EOS_SITE_NAME}


## @var EOS_SITE_PATH
## @brief Directory path of EOS hosted website
## @ingroup LegacyReleasing
declare -rx EOS_SITE_PATH=/eos/project/c/cmsgemdaq/www/cmsgemdaq


## @var GEM_DAQ_PKGS
## @brief Short names for repositories
## @ingroup LegacyReleasing
declare -rx -A GEM_DAQ_PKGS=(
    [cmsgemos]=cmsgemos
    [ctp7_modules]=ctp7_modules
    [gemctp7user]=gemctp7user
    [gemplotting]=gem-plotting-tools
    [reedmuller]=reedmuller-c
    [reg_utils]=reg_utils
    [vfatqc]=vfatqc-python-scripts
    [xhal]=xhal
)


## @var GEM_DAQ_BRANCHES
## @brief Legacy branches for repositories
## @ingroup LegacyReleasing
declare -rx -A GEM_DAQ_BRANCHES=(
    [cmsgemos]=release/legacy-1.0
    [ctp7_modules]=release/legacy-1.1
    [gemctp7user]=master
    [gemplotting]=release/legacy-1.5
    [reedmuller]=master
    [reg_utils]=release/legacy-1.1
    [vfatqc]=release/legacy
    [xhal]=release/legacy-1.0
)


## @var gpgdir
## @brief temporary location of GPGHOME, cleaned up on exit
## @ingroup LegacyReleasing
declare -rx gpgdir=$(mktemp -d /tmp/tmp.XXXXXX)


## @var repodir
## @brief temporary location of local repository tree, cleaned up on exit
## @ingroup LegacyReleasing
declare -rx repodir=$(mktemp -d /tmp/tmp.XXXXXX)


## @var tmpdir
## @brief temporary location of cloned repository, cleaned up on exit
## @ingroup LegacyReleasing
declare -rx tmpdir=$(mktemp -d /tmp/tmp.XXXXXX)


## @var PKG_BUILD_LOG
## @brief Logfile for package build
## @ingroup LegacyReleasing
declare -x PKG_BUILD_LOG=


## @fn cleanup_mlr()
## @brief Ensure all temp dirs are removed on exit or error
## @ingroup LegacyReleasing
## @details Called in @c trap on
## @li @c EXIT
## @li @c SIGQUIT
## @li @c SIGINT
## @li @c SIGTERM
## @li @c SIGSEGV
cleanup_mlr() {
    if ! [ "$?" = "0" ]
    then
        exec 1>&3 2>&4
        printf "\033[1;31m%s \n\033[0m" "An error occurred while building."
        printf "\033[1;31m%s \n\033[0m" "Check the output or logfile(s) in (${tmpdir}) for more information"
    else
        exec 1>&3 2>&4
        if [ -n "${tmpdir}" ]
        then
            printf "\033[1;35m %s \n\033[0m" "Cleaning up ${tmpdir}"
            rm -rf ${tmpdir}
        fi

        if [ -n "${repodir}" ]
        then
            printf "\033[1;35m %s \n\033[0m" "Not cleaning up ${repodir}, if all artifacts successfully deployed, remove with:"
            printf "\033[1;37m \t%s \n\033[0m" "rm -rf ${repodir}"
        fi
    fi

    if [ -n "${gpgdir}" ]
    then
        printf "\033[1;35m %s \n\033[0m" "Cleaning up ${gpgdir}"
        find  ${gpgdir} -type f -fprint0 /dev/null -exec shred -n100 -u {} \;
        rm -rf ${gpgdir}
    fi

    printf "\033[1;32m%s \n\033[0m" "Cleanup finished, bye!"
}

trap cleanup_mlr EXIT SIGQUIT SIGINT SIGTERM SIGSEGV


## @fn usage_mlr()
## @brief Usage function for @ref make_legacy_release.sh
## @ingroup LegacyReleasing
usage_mlr() {
    cat <<EOF
Usage: $0 [options] <SW repository name>

 This tool will create a release version of the legacy software by doing:
   * create the required RPM packages
   * create a CTP7 filesystem tarball of packages for the CTP7
   * sign the artifacts with a GPG key
   * push artifacts to the repository
   * sign the yum repository

 The valid options for the repository name are:
   * cmsgemos
   * ctp7_modules
   * gemctp7user
   * gemplotting
   * reedmuller
   * reg_utils
   * vfatqc
   * xhal

 Notes:
   For the GPG signing to function, you need two things (if they are not set as
environment variables, you will be prompted for them):
     * GPG_SIGNING_KEY_PRIV, pointing to the private key used for signing
     * GPG_PASSPHRASE, the passphrase used to unlock this private key

EOF

    # kill -INT $$
    exit 1
}


## @fn make_repo()
## @brief Create a local tree of the EOS repository structure
## @ingroup LegacyReleasing
make_repo() {
    printf "\033[1;32m * %s \n\033[0m" "Creating EOS repository structure"
    mkdir -p ${REPO_DIR}/{tarballs,SRPMS,{peta_armv7l,centos7_x86_64}/{DEBUGRPMS,RPMS}}
}


## @fn prepare_rpms()
## @brief Copy generated RPMs to release tree
## @ingroup LegacyReleasing
prepare_rpms() {
    printf "\033[1;32m * %s \n\033[0m" "Collecting RPMs for ${PKG_NAME}"
    find . \( -iname '*.src.rpm' -not -iname "${PKG}.src.rpm" \) \
         -fprint0 /dev/null -exec mv -n -t ${REPO_DIR}/SRPMS {} \+
    find . \( -iname '*.arm*.rpm' -not -iname "${PKG}.arm*.rpm" \) \
         -fprint0 /dev/null -exec mv -n -t ${REPO_DIR}/peta_armv7l/RPMS {} \+
    find . \( -iname '*.peta*.rpm' -not -iname "${PKG}.arm*.rpm" \) \
         -fprint0 /dev/null -exec mv -n -t ${REPO_DIR}/peta_armv7l/RPMS {} \+
    find . -iname '*debug*.rpm' \
         -fprint0 /dev/null -exec mv -n -t ${REPO_DIR}/centos7_x86_64/DEBUGRPMS {} \+
    find . \( -iname '*.x86_64.rpm' -not -iname "${PKG}.x86_64.rpm" \) \
         -fprint0 /dev/null -exec mv -n -t ${REPO_DIR}/centos7_x86_64/RPMS {} \+
    find . -iname '*.noarch.rpm' \
         -fprint0 /dev/null -exec mv -n -t ${REPO_DIR}/centos7_x86_64/RPMS {} \+
}


## @fn prepare_tarballs()
## @brief Copy generated tarballs to release tree
## @ingroup LegacyReleasing
prepare_tarballs() {
    printf "\033[1;32m * %s \n\033[0m" "Collecting tarballs for ${PKG_NAME}"
    local -r pkg_name=$1
    mkdir -p ${REPO_DIR}/tarballs/${pkg_name}
    find . \( -path '*/SOURCES' -o -path '*/repos' \) -prune -o \
         \( -iname '*.tbz2' -o -iname '*.tar.gz' -o -iname '*.tgz' -o -iname '*.zip' \) \
         -fprint0 /dev/null -exec cp -rfp -t ${REPO_DIR}/tarballs/${pkg_name} {} \+
}


## @fn make_api_tree()
## @brief Create a local tree of the EOS API structure
## @ingroup LegacyReleasing
make_api_tree() {
    printf "\033[1;32m * %s \n\033[0m" "Creating EOS API structure"
    mkdir -p ${DOCS_DIR}/api
}


## @fn prepare_docs()
## @brief Copy generated documentation to release tree
## @ingroup LegacyReleasing
prepare_docs() {
    printf "\033[1;32m * %s \n\033[0m" "Collecting API docs for ${PKG_NAME}"
    API_VERSION=${1##*v}
    mkdir -p ${DOCS_DIR}/api/${PKG}
    rsync -ahcXq --delete --info=progress2 --partial \
	  ./doc/build/html/ \
	  ${DOCS_DIR}/api/${PKG}/${API_VERSION}
    ln -s ${API_VERSION} ${DOCS_DIR}/api/${PKG}/latest
    find ${DOCS_DIR}/api/${PKG} -type f -iname '*.html' -fprint0 /dev/null -exec \
	 perl -pi -e "s|SITE_ROOT|${EOS_SITE_NAME}|g" {} \+
    find ${DOCS_DIR}/api/${PKG} -type f -iname '*.html' -fprint0 /dev/null -exec \
	 perl -pi -e "s|http://0.0.0.0:8000/|/|g" {} \+
    find ${DOCS_DIR}/api/${PKG} -type f -iname '*.html' -fprint0 /dev/null -exec \
	 perl -pi -e "s|http://0.0.0.0:8000|/|g" {} \+
    find ${DOCS_DIR}/api/${PKG} -type f -iname '*.html' -fprint0 /dev/null -exec \
	 perl -pi -e "s|href=\"${EOS_SITE_URL}|href=\"/${EOS_SITE_NAME}|g" {} \+
}


## @fn sign_rpms()
## @brief Sign generated RPMs with GPG key
## @ingroup LegacyReleasing
sign_rpms() {
    printf "\033[1;32m * %s \n\033[0m" "Signing RPMs"
    find ${REPO_DIR}/ -iname '*.rpm' -fprint0 /dev/null -exec \
         sh -ec '(echo set timeout -1; \
echo    spawn rpmsign --resign {}; \
echo expect -exact \"Enter pass phrase:\"; \
echo send -- \"${GPG_PASSPHRASE}\\r\"; \
echo expect eof; ) | expect' \; >> ${PKG_BUILD_LOG} 2>&1
}


## @fn sign_tarballs()
## @brief Sign generated tarballs with GPG key
## @ingroup LegacyReleasing
sign_tarballs() {
    printf "\033[1;32m * %s \n\033[0m" "Signing tarballs"
    find ${REPO_DIR}/tarballs -type f -fprint0 /dev/null -exec \
         sh -c "echo ${GPG_PASSPHRASE} | gpg --batch --yes --passphrase-fd 0 --detach-sign --armor {}" \;
}


## @fn publish_repo()
## @brief Push artifacts to EOS repository
## @ingroup LegacyReleasing
publish_repo() {
    printf "\033[1;32m * %s \n\033[0m" "Publishing RPMs to EOS"
    rsync -ahcXq --progress --partial ${REPO_DIR}/ \
          ${USER}@lxplus.cern.ch:${EOS_SITE_PATH}/sw/gemos/repos/releases/legacy/base/
}


## @fn sign_repo()
## @brief Sign repo files with GPG key
## @ingroup LegacyReleasing
sign_repo() {
    printf "\033[1;32m * %s \n\033[0m" "Signing EOS yum repository"
    local repofiles=()
    ssh lxplus.cern.ch << EOF > tmpfiles
find ${EOS_SITE_PATH}/sw/gemos/repos/releases/legacy/base -type f -iname '*.xml' -print0
EOF

    while IFS=  read -r -d $'\0'
    do
        repofiles+=("$REPLY")
    done < tmpfiles

    for f in ${repofiles[@]}
    do
        scp lxplus.cern.ch:$f .
        echo ${GPG_PASSPHRASE} | gpg --batch --yes --passphrase-fd 0 --detach-sign -a $(basename $f);
        ls -l $(basename $f)*;
        scp $(basename $f)* lxplus.cern.ch:${f%%$(basename $f)}
        shred -n100 -u $(basename $f)
        shred -n100 -u $(basename $f).asc
    done
    shred -n100 -u tmpfiles
}


## @fn publish_docs()
## @brief Push API artifacts to EOS repository
## @ingroup LegacyReleasing
publish_docs() {
    printf "\033[1;32m * %s \n\033[0m" "Publishing API docs on EOS"
    rsync -ahcXq --progress --partial ${DOCS_DIR}/api/ \
          ${USER}@lxplus.cern.ch:${EOS_SITE_PATH}/docs/api/
}


## @fn update_tag()
## @brief Bump and push the tag of the repository before building
## @ingroup LegacyReleasing
update_tag() {
    git fetch --all -p > /dev/null 2>&1

    local new_tag=

    set +e
    local -r hash_tag=$(git describe --tags 2>/dev/null)
    set -e
    local -r base_tag=${hash_tag%%-*}

    if [ -n "${base_tag}" ]
    then
        printf "\033[1;36m %s \n\033[0m" "Found base tag of ${base_tag} from ${hash_tag}"
        local -r maj_ver=$(echo ${base_tag} | awk '{split($$0,a,"."); print a[1]}')
        local -r min_ver=$(echo ${base_tag} | awk '{split($$0,a,"."); print a[2]}')
        local -r pat_ver=$(echo ${base_tag} | awk '{split($$0,a,"."); print a[3]}')

        set +e
        read -r -t5 -n1 -p $'\033[1;33mSelect tagging action: [m(minor)|p(patch)|N(no action, selected after 5 seconds)]:\033[0m ' TAG_ACTION
        set -e
        case ${TAG_ACTION} in
            [Mm]) echo
                  printf "\033[1;34m %s \n\033[0m" "Bumping minor version number"
                  new_tag=${maj_ver}.$((${min_ver}+1)).0
                  ;;
            [Pp]) echo
                  printf "\033[1;34m %s \n\033[0m" "Bumping patch version number"
                  new_tag=${maj_ver}.${min_ver}.$((${pat_ver}+1))
                  ;;
            *)    echo
                  printf "\033[1;34m %s \n\033[0m" "No tagging action specified, building with current tag"
                  ;;
        esac

        if [ -n "${new_tag}" ]
        then
            git tag -a -m "tagging for posterity, not for reality" ${new_tag}
            printf "\033[1;37m\t%s \n\033[0m" "git push -u origin ${new_tag}"
        else
            new_tag=${maj_ver}.${min_ver}.${pat_ver}
        fi
    else
        new_tag=$(git describe --tags --always 2>/dev/null)
        printf "\033[1;36m %s \n\033[0m" "No tag found, current hash is ${new_tag}"
    fi

    PKG_VER=${new_tag}
    printf "\033[1;36m %s \n\033[0m" "Current tag is ${PKG_VER}"
}


## @fn make_cmsgemos_xdaq()
## @brief Build the cmsgemos xdaq packages
## @ingroup LegacyReleasing
## @details The xdaq code used for legacy comes from the slice test branch,
##          but with a recent hotfix applied for mocking the TTS Resync sequence
make_cmsgemos_xdaq() {
    git co -t origin/legacy/QC8-run-control

    make -j8 >> ${PKG_BUILD_LOG} 2>&1
    make rpm >> ${PKG_BUILD_LOG} 2>&1

    pushd gempython >> ${PKG_BUILD_LOG} 2>&1
    make cleanrpm >> ${PKG_BUILD_LOG} 2>&1
    make clean >> ${PKG_BUILD_LOG} 2>&1
    popd >> ${PKG_BUILD_LOG} 2>&1

    prepare_rpms
    prepare_tarballs cmsgemos

    make cleanrpm >> ${PKG_BUILD_LOG} 2>&1
    make clean >> ${PKG_BUILD_LOG} 2>&1

    printf "\033[1;34m %s \n\033[0m" "Done compiling legacy xdaq, switching back to ${GEM_DAQ_BRANCHES[cmsgemos]}"
    git co ${GEM_DAQ_BRANCHES[cmsgemos]}
}


## @fn make_ctp7_tarball()
## @brief Create a CTP7 filesystem tarball
## @ingroup LegacyReleasing
## @details Done for all packages that must be installed on the back-end
make_ctp7_tarball() {
    printf "\033[1;32m * %s \n\033[0m" "Creating CTP7 filesystem package for ${PKG_NAME}"
    mkdir -p mnt/persistent/gemdaq/lib

    find . \( -path '*/rpm' -o -path '*/pkg' \) -prune -o \
         -wholename '*arm/lib/*.so*' \
         -exec cp -rfp -t mnt/persistent/gemdaq/lib {} \+

    find . -iname "${PKG}.*.rpm" -exec rm {} \+
    local rpm_name=$(ls ./**/*.arm*.rpm | egrep -v 'devel|debug')
    rpm_name=${rpm_name##*/}
    rpm_name=${rpm_name%%git*}git
    local -r pkg_name=$(echo ${rpm_name}|awk '{split($$0,a,"-"); print a[1];}')
    local -r pkg_ver=$(echo ${rpm_name}|awk '{split($$0,a,"-"); print a[2];}')
    local -r pkg_rpm_rel=$(echo ${rpm_name}|awk '{split($$0,a,"-"); print a[3];}')

    tar czf ${pkg_name}-${pkg_ver}-${pkg_rpm_rel}.tgz mnt
    ln -s ${pkg_name}-${pkg_ver}-${pkg_rpm_rel}.tgz ${pkg_name}-${pkg_ver}.tgz
    ln -s ${pkg_name}-${pkg_ver}.tgz ${pkg_name}.tgz

    mkdir -p ${REPO_DIR}/tarballs/${pkg_name}/
    mv ${pkg_name}*.tgz ${REPO_DIR}/tarballs/${pkg_name}/

    rm -rf mnt
}


## @fn make_ctp7mod_tarball()
## @brief Create a CTP7 filesystem tarball for the CTP7 modules
## @ingroup LegacyReleasing
## @details Done for ctp7_modules specifically, but could be useful for any
##          package that is built separately for GE1/1 and GE2/1
make_ctp7mod_tarball() {
    printf "\033[1;32m * %s \n\033[0m" "Creating CTP7 filesystem package for ${PKG_NAME}"
    mkdir -p mnt/persistent/rpcmodules

    cp -rfp lib/*.so* mnt/persistent/rpcmodules/

    find . -iname "${PKG}.*.rpm" -exec rm {} \+
    local rpm_name=$(ls rpm/*.rpm|egrep -v devel)
    rpm_name=${rpm_name##*/}
    rpm_name=${rpm_name%%git*}git
    local -r pkg_name=$(echo ${rpm_name}    | awk '{split($$0,a,"-"); print a[1];}')
    local -r pkg_ver=$(echo ${rpm_name}     | awk '{split($$0,a,"-"); print a[2];}')
    local -r pkg_rpm_rel=$(echo ${rpm_name} | awk '{split($$0,a,"-"); print a[3];}')
    local -r pkg_gen=$(echo ${pkg_rpm_rel}  | awk '{n=split($$0,a,"."); print a[((n-1))];}')

    tar czf ${pkg_name}-${pkg_ver}-${pkg_rpm_rel}.tgz mnt
    ln -s ${pkg_name}-${pkg_ver}-${pkg_rpm_rel}.tgz ${pkg_name}-${pkg_ver}-${pkg_gen}.tgz
    ln -s ${pkg_name}-${pkg_ver}-${pkg_gen}.tgz ${pkg_name}-${pkg_gen}.tgz

    mkdir -p ${REPO_DIR}/tarballs/${pkg_name}/
    mv ${pkg_name}*.tgz ${REPO_DIR}/tarballs/${pkg_name}/

    rm -rf mnt
}


####################################### main script #######################################
## @fn make_legacy_release()
## @brief Main entry point to the release tool
## @ingroup LegacyReleasing
make_legacy_release() {
    if ! [ -n "$1" ]
    then
        printf "\033[1;31m %s \n\033[0m" "Please specify a valid package (or packages)"
        usage
    fi

    if ! [ -n "${GPG_SIGNING_KEY_PRIV}" ]
    then
        read -p $'\033[1;33mEnter the private key file:\033[0m ' GPG_SIGNING_KEY_PRIV
    fi

    if ! [ -f ${GPG_SIGNING_KEY_PRIV} ]
    then
        printf "\033[1;31m %s \n\033[0m" 'Invalid GPG keyfile specified'
        usage
    fi

    if ! [ -n "${GPG_PASSPHRASE}" ]
    then
        read -s -p $'\033[1;33mEnter the GPG passphrase:\033[0m ' GPG_PASSPHRASE
    fi

    PKG_BUILD_LOG=${tmpdir}/release.log

    printf "\033[1;32m * %s \n\033[0m" "Importing GPG key"
    export GNUPGHOME=${gpgdir}
    chmod go-rwx ${GNUPGHOME}
    cat ${GPG_SIGNING_KEY_PRIV} | gpg -v --import >> ${PKG_BUILD_LOG} 2>&1

    printf "\033[1;36m %s \n\033[0m" "tmpdir is ${tmpdir}"
    pushd ${tmpdir} >> ${PKG_BUILD_LOG} 2>&1

    export REPO_DIR=${repodir}/repos
    export CONDA_DIR=${repodir}/conda
    export ENV_NAME=$(mktemp docs.XXXXXX)
    export DOCS_DIR=${repodir}/docs

    make_repo
    make_api_tree

    export BUILD_HOME=${PWD}
    export PETA_STAGE=/opt/gem-peta-stage/ctp7

    declare -ra PKGS=( "$@" )

    for PKG in "${PKGS[@]}"
    do
        if ! [ -n "${GEM_DAQ_PKGS[${PKG}]}" ]
        then
            printf "\033[1;91m %s \n\033[0m" "Invalid package (${PKG}) specified"
            continue
        fi

        declare -x PKG_NAME=${GEM_DAQ_PKGS[${PKG}]}

        PKG_BUILD_LOG=${tmpdir}/${PKG_NAME}.log

        printf "\033[1;32m * %s \n\033[0m" "Checking out package ${PKG_NAME}"
        git clone --recurse-submodules -b ${GEM_DAQ_BRANCHES[${PKG}]} git@github.com:cms-gem-daq-project/${PKG_NAME}.git >> ${PKG_BUILD_LOG} 2>&1
        # git clone --recurse-submodules -b ${GEM_DAQ_BRANCHES[${PKG}]} https://:@gitlab.cern.ch:8443/sturdy/${PKG_NAME}.git >> ${PKG_BUILD_LOG} 2>&1

        pushd ${PKG_NAME} >> ${PKG_BUILD_LOG} 2>&1
        declare -x PKG_VER=
        update_tag
        printf "\033[1;34m %s \n\033[0m" "Building ${PKG_NAME} for tag ${PKG_VER}, logfile is ${PKG_BUILD_LOG}"

        if [[ ${PKG} =~ ctp7_mod ]]
        then
            for gen in ge11 ge21
            do
                printf "\033[1;94m \t%s \n\033[0m" "Building ${PKG_NAME} for ${gen}"
                export GEM_VARIANT=${gen}
                make rpm >> ${PKG_BUILD_LOG} 2>&1
                make_ctp7mod_tarball
                prepare_rpms
                prepare_tarballs ${PKG}
            done
        else
            if [[ ${PKG} =~ xhal|reedm|reg ]]
            then
                if [[ ${PKG} =~ xhal ]]
                then
                    . /opt/rh/devtoolset-6/enable
                fi
                make rpm >> ${PKG_BUILD_LOG} 2>&1
                make_ctp7_tarball
                make cleanrpm >> ${PKG_BUILD_LOG} 2>&1
                make clean >> ${PKG_BUILD_LOG} 2>&1
                make rpm >> ${PKG_BUILD_LOG} 2>&1
            elif [[ ${PKG} =~ cmsgemos ]]
            then
                set +e
                read -r -t5 -n1 -p $'\033[1;33mRebuild cmsgemos xdaq packages? [y|N(selected after 5 seconds)]\033[0m ' REPLY
                set -e
                case ${REPLY} in
                    [Yy]) echo
                          printf "\033[1;34m %s \n\033[0m" "Rebuilding updated xdaq packages for cmsgemos"
                          make_cmsgemos_xdaq
                          ;;
                    *) echo ;;
                esac
                make gempython >> ${PKG_BUILD_LOG} 2>&1
                make gempython.rpm >> ${PKG_BUILD_LOG} 2>&1
            else
                make rpm >> ${PKG_BUILD_LOG} 2>&1
            fi

            prepare_rpms
            prepare_tarballs ${PKG}
        fi

        set +e
        read -r -t5 -n1 -p $'\033[1;33mBuild updated documentation? [Y(selected after 5 seconds)|n]\033[0m ' REPLY
        set -e
        case ${REPLY} in
            [Nn]) echo ;;
            *) echo
               printf "\033[1;32m * %s \n\033[0m" "Compiling API documentation for ${PKG_NAME}"
               mkdir -p ${CONDA_DIR}
               USE_CONDA=YES USE_DOXYREST=YES make doc >> ${PKG_BUILD_LOG} 2>&1
               prepare_docs ${PKG_VER}
               ;;
        esac

        popd >> ${PKG_BUILD_LOG} 2>&1
    done

    PKG_BUILD_LOG=${tmpdir}/release.log

    sign_rpms
    sign_tarballs

    while true
    do
        read -u 3 -r -n 1 -p $'\033[1;33m\nPublish and sign repository? [y/N]:\033[0m ' REPLY
        case $REPLY in
            [yY]) echo
                  publish_repo
                  sign_repo
                  publish_docs
                  break ;;
            *)    echo ; break ;;
        esac
    done 3<&0

    popd

    printf "\033[1;32m * %s \n\033[0m" "Release building completed successfully!"
}

#### Run the main function
(make_legacy_release $@)
