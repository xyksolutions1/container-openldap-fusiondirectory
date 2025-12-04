#!/command/with-contenv bash
# SPDX-FileCopyrightText: © 2025 Nfrastack <code@nfrastack.com>
#
# SPDX-License-Identifier: MIT
source /container/base/functions/container/init
prepare_service 10-openldap

SERVICE_NAME="openldap-fusiondirectory"
FUSIONDIRECTORY_SCHEMA_PATH=${FUSIONDIRECTORY_SCHEMA_PATH:-"/etc/openldap/schema/fusiondirectory/"}
FUSIONDIRECTORY_SCHEMA_CUSTOM_PATH=${FUSIONDIRECTORY_SCHEMA_CUSTOM_PATH:-"/custom/fusiondirectory/schema/"}
FUSIONDIRECTORY_INSTALLED="${CONFIG_PATH%/}/container-openldap-fusiondirectory-was-installed"

schema_apply() {
    apply_schema_file() {
        local fdsm=/usr/local/bin/fusiondirectory-schema-manager
        schema_installed() {
            "${fdsm}" --list-schemas | awk 'NR>1'| awk '{print $1}' | sed "s|:$||g" | grep -q "$1"
        }

        local schema_file="$1"
        local schema_name="$2"
        local action="$3"

        if [ ! -f "${schema_file}" ]; then
            print_warn "Schema file ${schema_file} not found, skipping."
            return
        fi

        if [ "$action" = "force" ]; then
            if schema_installed "$schema_name"; then
                print_notice "Replacing ${schema_name} schema"
                silent "${fdsm}" --replace-schema "${schema_file}"
                echo "$(TZ=$TIMEZONE date +'%Y-%m-%d %H:%M:%S %Z') | REPLACE ${schema_name}"|  silent tee -a "${FUSIONDIRECTORY_INSTALLED}"
            else
                print_notice "Inserting ${schema_name} schema"
                silent "${fdsm}" --insert-schema "${schema_file}"
                echo "$(TZ=$TIMEZONE date +'%Y-%m-%d %H:%M:%S %Z') | INSERT ${schema_name}" | silent tee -a "${FUSIONDIRECTORY_INSTALLED}"
            fi
        elif [ "$action" = "replace" ]; then
            if schema_installed "$schema_name"; then
                print_notice "Replacing ${schema_name} schema"
                silent "${fdsm}" --replace-schema "${schema_file}"
                echo "$(TZ=$TIMEZONE date +'%Y-%m-%d %H:%M:%S %Z') | REPLACE ${schema_name}" | silent tee -a "${FUSIONDIRECTORY_INSTALLED}"
            fi
        else # insert
            if ! schema_installed "$schema_name"; then
                print_notice "Inserting ${schema_name} schema"
                silent "${fdsm}" --insert-schema "${schema_file}"
                echo "$(TZ=$TIMEZONE date +'%Y-%m-%d %H:%M:%S %Z') | INSERT ${schema_name}" | silent tee -a "${FUSIONDIRECTORY_INSTALLED}"
            fi
        fi
    }

    local schema_paths=("${FUSIONDIRECTORY_SCHEMA_PATH}" "${FUSIONDIRECTORY_SCHEMA_CUSTOM_PATH}")
    for plugin in "$@"; do
        # Support plugin:action syntax, eg core:force
        local plugin_name="$plugin"
        local action="insert"
        if [[ "$plugin" == *:* ]]; then
            plugin_name="${plugin%%:*}"
            action="${plugin##*:}"
        else
            local env_var="PLUGIN_${plugin_name^^}"
            local env_val="${!env_var}"
            case "${env_val,,}" in
                force) action="replace" ;;
                true | yes ) action="insert" ;;
                *) action="skip" ;;
            esac
        fi
        if [ "$action" = "skip" ]; then continue ; fi

        local found=false
        local processed_schemas=()
        for search_path in "${schema_paths[@]}"; do
            mapfile -t plugin_schemas < <(ls -1 "${search_path%/}"/${plugin_name}*.schema 2>/dev/null | sort -u)
            for suffix in ".schema" "-fd.schema" "-fd-conf.schema"; do
                for schema_file in "${plugin_schemas[@]}"; do
                    if [[ "$schema_file" == *"${plugin_name}${suffix}" ]]; then
                        local schema_name
                        schema_name="$(basename "${schema_file}" .schema)"
                        if [[ ! " ${processed_schemas[@]} " =~ " ${schema_file} " ]]; then
                            apply_schema_file "${schema_file}" "${schema_name}" "${action}"
                            processed_schemas+=("$schema_file")
                            found=true
                        fi
                    fi
                done
            done
            for schema_file in "${plugin_schemas[@]}"; do
                if [[ ! "$schema_file" == *"-fd.schema" && ! "${schema_file}" == *"-fd-conf.schema" && "${schema_file}" == *".schema" ]]; then
                    local schema_name
                    schema_name="$(basename "${schema_file}" .schema)"
                    if [[ ! " ${processed_schemas[@]} " =~ " ${schema_file} " ]]; then
                        apply_schema_file "${schema_file}" "${schema_name}" "${action}"
                        processed_schemas+=("$schema_file")
                        found=true
                    fi
                fi
            done
        done
        if [ "$found" = "false" ]; then
            print_warn "No schema files found for plugin '${plugin_name}' in any schema path."
        fi
        for suffix in "-fd.schema" "-fd-conf.schema"; do
            for search_path in "${schema_paths[@]}"; do
                local schema_file="${search_path%/}/${plugin_name}${suffix}"
                if [ -f "$schema_file" ]; then
                    local schema_name
                    schema_name="${plugin_name}${suffix%.schema}"
                    if [[ ! " ${processed_schemas[@]} " =~ " ${schema_file} " ]]; then
                        apply_schema_file "${schema_file}" "${schema_name}" "${action}"
                        processed_schemas+=("${schema_file}")
                    fi
                fi
            done
        done
    done
}

if [ ! -e "${FUSIONDIRECTORY_INSTALLED}" ]; then
    print_warn "First time Fusion Directory install detected"
    if [ -z "${BASE_DN}" ]; then
        IFS='.' read -ra BASE_DN_TABLE <<<"$DOMAIN"
        for i in "${BASE_DN_TABLE[@]}"; do
            EXT="dc=$i,"
            BASE_DN=$BASE_DN$EXT
        done

        BASE_DN=${BASE_DN::-1}
    fi

    IFS='.' read -a domain_elems <<<"${DOMAIN}"
    SUFFIX=""
    ROOT=""

    for elem in "${domain_elems[@]}"; do
        if [ "x${SUFFIX}" = x ]; then
            SUFFIX="dc=${elem}"
            BASE_DN="${SUFFIX}"
            ROOT="${elem}"
        else
            BASE_DN="${BASE_DN},dc=${elem}"
        fi
    done

    transform_var file\
                        ADMIN_PASS \
                        FUSIONDIRECTORY_ADMIN_USER \
                        FUSIONDIRECTORY_ADMIN_PASS \
                        READONLY_USER_USER \
                        READONLY_USER_PASS

    CN_ADMIN="cn=admin,ou=aclroles,${BASE_DN}"
    CN_ADMIN_BS64="$(echo -n "${CN_ADMIN}" | base64 | tr -d '\n')"
    FUSIONDIRECTORY_ADMIN_USER=${FUSIONDIRECTORY_ADMIN_USER:-"fd-admin"}
    FUSIONDIRECTORY_ADMIN_PASS=${FUSIONDIRECTORY_ADMIN_PASS:-"admin"}
    ADMIN_PASS_ENCRYPTED="$(slappasswd -s "$ADMIN_PASS")"
    FUSIONDIRECTORY_ADMIN_PASS_ENCRYPTED="$(slappasswd -s "$FUSIONDIRECTORY_ADMIN_PASS")"
    READONLY_USER_PASS_ENCRYPTED="$(slappasswd -s "$READONLY_USER_PASS")"
    ORGANIZATION=${ORGANIZATION:-Example Organization}
    UID_FD_ADMIN="uid=${FUSIONDIRECTORY_ADMIN_USER},${BASE_DN}"
    UID_FD_ADMIN_BS64="$(echo -n "${UID_FD_ADMIN}" | base64 | tr -d '\n')"
    echo "$(TZ=$TIMEZONE date +'%Y-%m-%d %H:%M:%S %Z') | Fusion Directory Schema Version $(grep -o "ADD: FusionDirectory Schemas .* |" /container/build/${IMAGE_NAME/\//_}/build.log | awk '{print $4}')" | silent tee -a "${FUSIONDIRECTORY_INSTALLED}"
    schema_apply core:force ldapns:force template:force
    stage1=$(mktemp)
    cat <<EOF | silent tee ${stage1}
dn: ${BASE_DN}
changeType: add
o: ${ORGANIZATION}
dc: ${ROOT}
ou: ${ROOT}
description: ${ROOT}
objectClass: top
objectClass: dcObject
objectClass: organization
objectClass: gosaDepartment
objectClass: gosaAcl
gosaAclEntry: 0:subtree:${CN_ADMIN_BS64}:${UID_FD_ADMIN_BS64}

dn: cn=admin,${BASE_DN}
changeType: add
objectClass: simpleSecurityObject
objectClass: organizationalRole
cn: admin
description: LDAP administrator
userPassword: ${ADMIN_PASS_ENCRYPTED}
EOF

    silent ldapmodify -H 'ldapi:///' -D "cn=admin,${BASE_DN}" -w "${ADMIN_PASS}" -f ${stage1}
    if var_true "${ENABLE_READONLY_USER}"; then
        print_notice "Adding read only (DSA) user"
        ldapadd -H 'ldapi:///' -D "cn=admin,${BASE_DN}" -w "${ADMIN_PASS}" -f /container/data/openldap/config/bootstrap/ldif/readonly-user/readonly-user.ldif
        ldapmodify -H 'ldapi:///' -f /container/data/openldap/config/bootstrap/ldif/readonly-user/readonly-user-acl.ldif
    fi

    stage2=$(mktemp)
    cat <<EOF | silent tee ${stage2}
dn: uid=${FUSIONDIRECTORY_ADMIN_USER},${BASE_DN}
changeType: add
objectClass: inetOrgPerson
objectClass: organizationalPerson
objectClass: person
cn: System Administrator
sn: Administrator
givenName: System
uid: ${FUSIONDIRECTORY_ADMIN_USER}
userPassword: ${FUSIONDIRECTORY_ADMIN_PASS_ENCRYPTED}

dn: ou=aclroles,${BASE_DN}
changeType: add
objectClass: organizationalUnit
ou: aclroles

dn: cn=admin,ou=aclroles,${BASE_DN}
changeType: add
objectClass: top
objectClass: gosaRole
cn: admin
description: Gives all rights on all objects
gosaAclTemplate: 0:all;cmdrw

dn: cn=manager,ou=aclroles,${BASE_DN}
changeType: add
cn: manager
description: Give all rights on users in the given branch
objectClass: top
objectClass: gosaRole
gosaAclTemplate: 0:user/user;cmdrw,user/posixAccount;cmdrw

dn: cn=editowninfos,ou=aclroles,${BASE_DN}
changeType: add
cn: editowninfos
description: Allow users to edit their own information (main tab and posix use
  only on base)
objectClass: top
objectClass: gosaRole
gosaAclTemplate: 0:user/user;srw,user/posixAccount;srw

dn: cn=editownpwd,ou=aclroles,${BASE_DN}
changeType: add
cn: editownpwd
description: Allow users to edit their own password (use only on base)
objectClass: top
objectClass: gosaRole
gosaAclTemplate: 0:user/user;s#userPassword;rw

dn: ou=fusiondirectory,${BASE_DN}
changeType: add
objectClass: organizationalUnit
ou: fusiondirectory

dn: cn=config,ou=fusiondirectory,${BASE_DN}
changeType: add
fdTheme: breezy
fdTimezone: ${TIMEZONE}
fdLdapSizeLimit: 200
fdModificationDetectionAttribute: entryCSN
fdLogging: TRUE
fdSchemaCheck: TRUE
fdWildcardForeignKeys: TRUE
fdPasswordAllowedHashes: clear
fdPasswordAllowedHashes: crypt/blowfish
fdPasswordAllowedHashes: crypt/enhanced-des
fdPasswordAllowedHashes: crypt/md5
fdPasswordAllowedHashes: crypt/sha-256
fdPasswordAllowedHashes: crypt/sha-512
fdPasswordAllowedHashes: crypt/standard-des
fdPasswordAllowedHashes: empty
fdPasswordAllowedHashes: md5
fdPasswordAllowedHashes: sasl
fdPasswordAllowedHashes: sha
fdPasswordAllowedHashes: smd5
fdPasswordAllowedHashes: ssha
fdPasswordAllowedHashes: ssha512
fdPasswordDefaultHash: ssha
fdForcePasswordDefaultHash: FALSE
fdHandleExpiredAccounts: FALSE
fdLoginAttribute: uid
fdForceSSL: FALSE
fdLoginMethod: LoginPost
fdHttpHeaderAuthHeaderName: AUTH_USER
fdSslKeyPath: /etc/ssl/private/fd.key
fdSslCertPath: /etc/ssl/certs/fd.cert
fdSslCaCertPath: /etc/ssl/certs/ca.cert
fdCasServerCaCertPath: /etc/ssl/certs/ca.cert
fdCasHost: localhost
fdCasPort: 443
fdCasContext: /cas
fdCasVerbose: FALSE
fdCasLibraryBool: FALSE
fdAccountPrimaryAttribute: uid
fdCnPattern: %givenName% %sn%
fdGivenNameRequired: TRUE
fdStrictNamingRules: TRUE
fdUserRDN: ou=people
fdAclRoleRDN: ou=aclroles
fdRestrictRoleMembers: FALSE
fdSplitPostalAddress: FALSE
fdMaxAvatarSize: 200
fdDisplayErrors: FALSE
fdLdapStats: FALSE
fdDebugLevel: 0
fdDebugLogging: FALSE
fdListSummary: TRUE
fdAclTabOnObjects: FALSE
fdAclTargetFilterLimit: 100
cn: config
fdDisplayHookOutput: FALSE
fdOGroupRDN: ou=groups
fdForceSaslPasswordAsk: FALSE
fdMailTemplateRDN: ou=mailTemplate
fdPasswordRecoveryActivated: FALSE
fdPasswordRecoveryEmail: to.be@chang.ed
fdPasswordRecoveryValidity: 10
fdPasswordRecoverySalt: SomethingSecretAndVeryLong
fdPasswordRecoveryUseAlternate: FALSE
fdPasswordRecoveryLoginAttribute: uid
fdPasswordRecoveryMailSubject: [FusionDirectory] Password recovery link
fdPasswordRecoveryMailBody:: SGVsbG8sCgpIZXJlIGlzIHlvdXIgaW5mb3JtYXRpb246IAogL
 SBMb2dpbiA6ICVzCiAtIExpbmsgOiAlcwoKVGhpcyBsaW5rIGlzIG9ubHkgdmFsaWQgZm9yIDEwIG
 1pbnV0ZXMu
fdPasswordRecoveryMail2Subject: [FusionDirectory] Password recovery successful
fdPasswordRecoveryMail2Body:: SGVsbG8sCgpZb3VyIHBhc3N3b3JkIGhhcyBiZWVuIGNoYW5n
 ZWQuCllvdXIgbG9naW4gaXMgc3RpbGwgJXMu
fdTasksRDN: ou=tasks
objectClass: fusionDirectoryConf
objectClass: fusionDirectoryPluginsConf
objectClass: fdMailTemplateConf
objectClass: fdPasswordRecoveryConf
objectClass: fdTasksConf
fdEnableSnapshots: TRUE
fdEnableAutomaticSnapshots: FALSE
fdSnapshotBase: ou=snapshots,${BASE_DN}
fdWarnSSL: TRUE
fdSessionLifeTime: 3600
fusionConfigMd5: 7fd38d273a2f2e14c749467f4c38a650
fdGroupRDN: ou=groups
fdShells: /bin/bash
fdShells: /bin/sh
fdShells: /sbin/nologin
fdShells: /bin/false
fdMinId: 100
fdUidNumberBase: 1100
fdGidNumberBase: 1100
fdIdAllocationMethod: traditional

dn: ou=locks,ou=fusiondirectory,${BASE_DN}
changeType: add
objectClass: organizationalUnit
ou: locks

dn: ou=snapshots,${BASE_DN}
changeType: add
objectClass: organizationalUnit
ou: snapshots
EOF

    silent ldapadd -H 'ldapi:///' -D "cn=admin,${BASE_DN}" -w "${ADMIN_PASS}" -f ${stage2}

    print_notice "Adding ppolicy defaults"
    sed -i "s|{{BASE_DN}}|${BASE_DN}|g" \
                                           /container/data/openldap/config/ppolicy/01-ppolicy-config.ldif \
                                           /container/data/openldap/config/ppolicy/02-ppolicy-ou.ldif \
                                           /container/data/openldap/config/ppolicy/03-ppolicy-default.ldif

    silent ldapadd -Y EXTERNAL -Q -H ldapi:/// -f /container/data/openldap/config/ppolicy/01-ppolicy-config.ldif
    silent ldapadd -H 'ldapi:///' -D "cn=admin,${BASE_DN}" -w "${ADMIN_PASS}" -f /container/data/openldap/config/ppolicy/02-ppolicy-ou.ldif
    silent ldapadd -H 'ldapi:///' -D "cn=admin,${BASE_DN}" -w "${ADMIN_PASS}" -f /container/data/openldap/config/ppolicy/03-ppolicy-default.ldif
fi

# Dynamically discover enabled plugins from environment
enabled_plugins=()
for env in $(set -o posix; set | grep '^PLUGIN_.*=' | grep -iE '=true|=force'); do
    plugin_name="${env%%=*}"
    plugin_name="${plugin_name#PLUGIN_}"
    plugin_name="${plugin_name,,}"
    enabled_plugins+=("$plugin_name")
done

# Sort plugins: mail, audit, systems first, then rest
sorted_plugins=()
for p in mail audit systems; do
    for i in "${!enabled_plugins[@]}"; do
        if [[ "${enabled_plugins[$i]}" == "$p" ]]; then
            sorted_plugins+=("$p")
            unset 'enabled_plugins[i]'
        fi
    done
done
# Add remaining plugins
for p in "${enabled_plugins[@]}"; do
    sorted_plugins+=("$p")
done

# Apply schemas for sorted plugins
schema_apply "${sorted_plugins[@]}"

