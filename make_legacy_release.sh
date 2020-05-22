#!/bin/bash -e

shopt -s globstar

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

## @var GEM_DAQ_PKGS
## @brief Short names for repositories
## @ingroup LegacyReleasing
declare -r -A GEM_DAQ_PKGS=(
    [cmsgemos]=cmsgemos
    [ctp7_modules]=ctp7_modules
    [gemplotting]=gem-plotting-tools
    [reedmuller]=reedmuller-c
    [rwreg]=reg_utils
    [vfatqc]=vfatqc-python-scripts
    [xhal]=xhal
)

## @var GEM_DAQ_BRANCHES
## @brief Legacy branches for repositories
## @ingroup LegacyReleasing
declare -r -A GEM_DAQ_BRANCHES=(
    [cmsgemos]=release/legacy-1.0
    [ctp7_modules]=release/legacy-1.1
    [gemplotting]=release/legacy-1.5
    [reedmuller]=master
    [rwreg]=release/legacy-1.1
    [vfatqc]=release/legacy
    [xhal]=release/legacy-1.0
)

## @var gpgdir
## @brief temporary location of GPGHOME, cleaned up on exit
## @ingroup LegacyReleasing
declare gpgdir=

## @var tmpdir
## @brief temporary location of cloned repository, cleaned up on exit
## @ingroup LegacyReleasing
declare tmpdir=

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
        printf "\033[1;31m %s \n\033[0m" "An error occurred, check the output or log"
    fi

    if [ -n "${tmpdir}" ]
    then
        printf "\033[1;35m %s \n\033[0m" "Cleaning up ${tmpdir}"
        rm -rf ${tmpdir}
    fi

    if [ -n "${gpgdir}" ]
    then
        printf "\033[1;35m %s \n\033[0m" "Cleaning up ${gpgdir}"
        find  ${gpgdir} -type f -print0 -exec shred -n100 -u {} \;
        rm -rf ${gpgdir}
    fi

    if [ -n "${repodir}" ]
    then
        printf "\033[1;35m %s \n\033[0m" "Not cleaning up ${repodir},if all artifacts successfully deployed, remove with:"
        printf "\033[1;37m %s \n\033[0m" "rm -rf ${repodir}"
    fi

    printf "\033[1;32m %s \n\033[0m" "Cleanup finished, bye!"
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
    mkdir -p ${REPO_DIR}/{tarballs,SRPMS,{peta_armv7l,centos7_x86_64}/{DEBUGRPMS,RPMS}}
}


## @fn prepare_rpms()
## @brief Copy generated RPMs to release tree
## @ingroup LegacyReleasing
prepare_rpms() {
    find . -iname '*.src.rpm'    -print0 -exec mv -t ${REPO_DIR}/SRPMS {} \+
    find . -iname '*.arm.rpm'    -print0 -exec mv -t ${REPO_DIR}/peta_armv7l/RPMS {} \+
    find . -iname '*.peta*.rpm'  -print0 -exec mv -t ${REPO_DIR}/peta_armv7l/RPMS {} \+
    find . -iname '*debug*.rpm'  -print0 -exec mv -t ${REPO_DIR}/centos7_x86_64/DEBUGRPMS {} \+
    find . -iname '*.x86_64.rpm' -print0 -exec mv -t ${REPO_DIR}/centos7_x86_64/RPMS {} \+
    find . -iname '*.noarch.rpm' -print0 -exec mv -t ${REPO_DIR}/centos7_x86_64/RPMS {} \+
}

## @fn prepare_tarballs()
## @brief Copy generated tarballs to release tree
## @ingroup LegacyReleasing
prepare_tarballs() {
    local -r pkg_name=$1
    mkdir -p ${REPO_DIR}/tarballs/${pkg_name}
    find . -path '*/SOURCES' -prune -o \
         \( -iname '*.tbz2' -o -iname '*.tar.gz' -o -iname '*.tgz' -o -iname '*.zip' \) \
         -print0 -exec cp -rfp -t ${REPO_DIR}/tarballs/${pkg_name} {} \+
}

## @fn sign_rpms()
## @brief Sign generated RPMs with GPG key
## @ingroup LegacyReleasing
sign_rpms() {
    find ${REPO_DIR}/ -iname '*.rpm' -print0 -exec \
         sh -ec '(echo set timeout -1; \
echo    spawn rpmsign --resign {}; \
echo expect -exact \"Enter pass phrase:\"; \
echo send -- \"${GPG_PASSPHRASE}\\r\"; \
echo expect eof; ) | expect' \;
}

## @fn sign_tarballs()
## @brief Sign generated tarballs with GPG key
## @ingroup LegacyReleasing
sign_tarballs() {
    find ${REPO_DIR}/tarballs -type f -print0 -exec \
         sh -c "echo ${GPG_PASSPHRASE} | gpg --batch --yes --passphrase-fd 0 --detach-sign --armor {}" \;
}
## @fn publish_repo()
## @brief Push artifacts to EOS repository
## @ingroup LegacyReleasing
publish_repo() {
    rsync -ahcX --progress --partial repos/ ${USER}@lxplus.cern.ch:/eos/project/c/cmsgemdaq/www/cmsgemdaq/sw/gemos/repos/releases/legacy/base/
}

## @fn sign_repo()
## @brief Sign repo files with GPG key
## @ingroup LegacyReleasing
sign_repo() {
    local repofiles=()
    ssh lxplus.cern.ch << EOF > tmpfiles
find /eos/project/c/cmsgemdaq/www/cmsgemdaq/sw/gemos/repos/releases/legacy/base -type f -iname '*.xml' -print0
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

## @fn update_tag()
## @brief Bump and push the tag of the repository before building
## @ingroup LegacyReleasing
update_tag() {
    git fetch --all -p

    local -r hash_tag=$(git describe --tags)
    local -r base_tag=${hash_tag%%-*}
    printf "\033[1;36m %s \n\033[0m" "Found base tag of ${base_tag} from ${hash_tag}"
    local -r maj_ver=$(echo ${base_tag} | awk '{split($$0,a,"."); print a[1]}')
    local -r min_ver=$(echo ${base_tag} | awk '{split($$0,a,"."); print a[2]}')
    local -r pat_ver=$(echo ${base_tag} | awk '{split($$0,a,"."); print a[3]}')

    local new_tag=
    read -r -n1 -p $'\033[1;33mSelect tagging action (any other key for no new tag): [m(minor)|p(patch)|N(no action)]:\033[0m ' TAG_ACTION
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
        printf "\033[1;32m %s \n\033[0m" "git push -u origin ${new_tag}"
    fi
}

## @fn make_cmsgemos_xdaq()
## @brief Build the cmsgemos xdaq packages
## @ingroup LegacyReleasing
## @details The xdaq code used for legacy comes from the slice test branch,
##          but with a recent hotfix applied for mocking the TTS Resync sequence
make_cmsgemos_xdaq() {
    git co -t origin/legacy/QC8-run-control

    make -j8
    make rpm

    pushd gempython
    make clean
    make cleanrpm
    popd

    prepare_rpms
    prepare_tarballs cmsgemos

    make cleanrpm
    make clean

    git co ${GEM_DAQ_BRANCHES[cmsgemos]}
}

## @fn make_ctp7_tarball()
## @brief Create a CTP7 filesystem tarball
## @ingroup LegacyReleasing
## @details Done for all packages that must be installed on the back-end
make_ctp7_tarball() {
    mkdir -p mnt/persistent/gemdaq/lib

    cp -rfp ./**/*arm/lib/*.so mnt/persistent/gemdaq/lib

    local rpm_name=$(ls ./**/rpm/*.arm.rpm | egrep -v devel)
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
    mkdir -p mnt/persistent/rpcmodules

    cp -rfp lib/*.so mnt/persistent/rpcmodules/

    local rpm_name=$(ls rpm/*.rpm|egrep -v devel)
    rpm_name=${rpm_name##*/}
    rpm_name=${rpm_name%%git*}git
    local -r pkg_name=$(echo ${rpm_name}    | awk '{split($$0,a,"-"); print a[1];}')
    local -r pkg_ver=$(echo ${rpm_name}     | awk '{split($$0,a,"-"); print a[2];}')
    local -r pkg_rpm_rel=$(echo ${rpm_name} | awk '{split($$0,a,"-"); print a[3];}')
    local -r pkg_gen=$(echo ${pkg_rpm_rel}  | awk '{split($$0,a,"."); print a[2];}')

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

    declare -r gpgdir=$(mktemp -d /tmp/tmp.XXXXXX)
    export GNUPGHOME=${gpgdir}
    chmod go-rwx ${GNUPGHOME}
    cat ${GPG_SIGNING_KEY_PRIV} | gpg -v --import

    declare -r tmpdir=$(mktemp -d /tmp/tmp.XXXXXX)
    printf "\033[1;36m %s \n\033[0m" "tmpdir is ${tmpdir}"
    pushd ${tmpdir}

    declare -r repodir=$(mktemp -d /tmp/tmp.XXXXXX)
    export REPO_DIR=${repodir}/repos
    make_repo

    export BUILD_HOME=${PWD}
    export PETA_STAGE=/opt/gem-peta-stage/ctp7

    declare -ra PKGS=( "$@" )

    for PKG in "${PKGS[@]}"
    do
        if ! [ -n "${GEM_DAQ_PKGS[${PKG}]}" ]
        then
            printf "\033[1;31m %s \n\033[0m" "Invalid package (${PKG}) specified"
            continue
        fi

        declare PKG_NAME=${GEM_DAQ_PKGS[${PKG}]}

        git clone --recurse-submodules -b ${GEM_DAQ_BRANCHES[${PKG}]} git@github.com:cms-gem-daq-project/${PKG_NAME}.git

        pushd ${PKG_NAME}

        update_tag

        if [[ ${PKG} =~ ctp7_mod ]]
        then
            for gen in ge11 ge21
            do
                export GEM_VARIANT=${gen}
                make rpm
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
                make rpm
                make_ctp7_tarball
            elif [[ ${PKG} =~ cmsgemos ]]
            then
                read -r -n1 -p $'\033[1;33mRebuild cmsgemos xdaq packages? [y|N]\033[0m ' REPLY
                case ${REPLY} in
                    [Yy]) echo
                          printf "\033[1;34m %s \n\033[0m" "Rebuilding updated xdaq packages for cmsgemos"
                          make_cmsgemos_xdaq
                          ;;
                    *) echo ;;
                esac
                make gempython && make gempython.rpm
            else
                make rpm
            fi

            prepare_rpms
            prepare_tarballs ${PKG}
        fi

        popd
    done

    sign_rpms
    sign_tarballs

    while true
    do
        read -u 3 -r -n 1 -p $'\033[1;33m\nPublish and sign repository? [y/N]:\033[0m ' REPLY
        case $REPLY in
            [yY]) echo
                  publish_repo
                  sign_repo
                  break ;;
            *)    echo ; break ;;
        esac
    done 3<&0
}

#### Run the main function
(make_legacy_release $@)
