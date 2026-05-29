/*
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : SfAiAgentController
 * Author          : Abu Awaish
 * Created Date    : May 7, 2026
 * Last Modified By: Abu Awaish
 * Last Modified On: May 19, 2026
 * Description     : SF AI Agent — intent-aware routing, native org queries,
 *                   dynamic SOQL execution, OpenAI GPT-4 fallback.
 *                   Supports: object metadata, fields, children, picklists,
 *                   permission sets, profiles, roles, users, flows, apex classes,
 *                   record types, OWD, installed packages, custom objects.
 *
 */
public with sharing class SfAiAgentController {

    // ── Tooling API objects — cannot be queried via Database.query() ───────────
    private static final Set<String> TOOLING_ONLY_OBJECTS = new Set<String>{
        'validationrule', 'workflowrule', 'workflowalert', 'workflowfieldupdate',
        'workflowtask', 'workflowsend', 'workflowoutboundmessage',
        'apextriggermetadata', 'customfield', 'customobject',
        'layoutassignment', 'profilelayout', 'weblink', 'businessprocess'
    };

    // ══════════════════════════════════════════════════════════════════════════
    // ENTRY POINT
    // ══════════════════════════════════════════════════════════════════════════

    @AuraEnabled
    public static String askAgent(String prompt) {
        try {
            if (String.isBlank(prompt)) {
                throw new AuraHandledException('Prompt cannot be empty.');
            }

            // 1. Code/explanation → GPT
            if (isCodeOrExplanationRequest(prompt)) {
                return callOpenAIChat(prompt);
            }

            // 2. Native org handlers
            String nativeResult = tryNativeOrgHandler(prompt);
            if (nativeResult != null) return nativeResult;

            // 3. GPT generates SOQL → execute
            String soql = generateSoqlQuery(prompt);
            if (isValidSelectQuery(soql)) {
                return executeSoqlAndFormat(soql);
            }

            // 4. General GPT answer
            return callOpenAIChat(prompt);

        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            System.debug('Exception: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new AuraHandledException('Unexpected error: ' + e.getMessage());
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // INTENT DETECTION
    // ══════════════════════════════════════════════════════════════════════════

    private static Boolean isCodeOrExplanationRequest(String prompt) {
        String lp = prompt.toLowerCase();
        return lp.contains('write apex')          || lp.contains('create apex')       ||
               lp.contains('write a trigger')     || lp.contains('write trigger')     ||
               lp.contains('create trigger')      || lp.contains('write lwc')         ||
               lp.contains('create lwc')          || lp.contains('lwc component')     ||
               lp.contains('how to ')             || lp.contains('how do i')          ||
               lp.contains('how does')            || lp.contains('explain ')          ||
               lp.contains('what is ')            || lp.contains('what are ')         ||
               lp.contains('difference between')  || lp.contains('best practice')     ||
               lp.contains('example of')          || lp.contains('syntax for')        ||
               lp.contains('write soql')          || lp.contains('give me soql')      ||
               lp.contains('only soql')           || lp.contains('generate soql')     ||
               lp.contains('soql for ')           || lp.contains('soql to ')          ||
               lp.contains('soql query')          || lp.contains('show me soql')      ||
               lp.contains('show me a soql')      || lp.contains('generate a soql')   ||
               lp.contains('create a soql')       || lp.contains('get soql')          ||
               lp.contains('need soql');
    }

    // ── Does the prompt want ONE specific record? ─────────────────────────────
    private static Boolean wantsSpecificRecord(String lp) {
        return lp.contains('detail')            || lp.contains('named ')           ||
               lp.contains('called ')           || lp.contains('equals')           ||
               lp.contains(' = ')               || lp.contains('about ')           ||
               lp.contains('specific')          || lp.contains('full')             ||
               lp.contains('whose name')        || lp.contains('info about')       ||
               lp.contains('information about') || lp.contains('tell me about')    ||
               lp.contains('show me info')      || lp.contains('"')                ||
               lp.contains('\'');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // NATIVE ORG HANDLER — priority-ordered routing
    // ══════════════════════════════════════════════════════════════════════════

    private static String tryNativeOrgHandler(String prompt) {
        String lp = prompt.toLowerCase();

        // ── PRIORITY 1 — Record/data fetch → SOQL generator ───────────────────
        Boolean isRecordFetch =
            lp.contains('top ')           || lp.contains('fetch ')        ||
            lp.contains('get me ')        || lp.contains('get top')       ||
            lp.contains('retrieve ')      || lp.contains('find me')       ||
            lp.contains('having id')      || lp.contains('where id')      ||
            lp.contains('limit ')         || lp.contains('only one')      ||
            lp.contains('one record')     || lp.contains('records of')    ||
            lp.contains('records from')   || lp.contains('records with')  ||
            (lp.contains('show me ') && lp.contains('record'));
        if (isRecordFetch) return null;

        // ── PRIORITY 2 — Current user info ────────────────────────────────────
        if (lp.contains('my username')   || lp.contains('who am i')      ||
            lp.contains('my email')      || lp.contains('my name')       ||
            lp.contains('current user')  || lp.contains('my user info')  ||
            lp.contains('my org')) {
            return getCurrentUserInfo();
        }

        // ── PRIORITY 3 — Picklist VALUES (dot notation) ───────────────────────
        if (lp.contains('.') &&
            (lp.contains('value') || lp.contains('lov') || lp.contains('option')) &&
            containsObjectName(lp)) {
            return getPicklistValues(prompt);
        }

        // ── PRIORITY 4 — Picklist FIELDS on object ────────────────────────────
        Boolean asksPicklistFields =
            lp.contains('picklist field')     || lp.contains('picklist on')    ||
            lp.contains('picklist in')        || lp.contains('picklists on')   ||
            lp.contains('picklists in')       || lp.contains('all picklist')   ||
            lp.contains('available picklist') || lp.contains('show picklist')  ||
            lp.contains('list picklist');
        if (asksPicklistFields && containsObjectName(lp)) {
            return getPicklistFields(prompt);
        }

        // ── PRIORITY 5 — Children only ─────────────────────────────────────────
        if ((lp.contains('child object')       ||
             lp.contains('child relationship') ||
             lp.contains('children of')        ||
             lp.contains('related object')) && containsObjectName(lp)) {
            return getObjectChildren(extractObjectName(prompt));
        }

        // ── PRIORITY 6 — Full describe (fields + children) ────────────────────
        Boolean asksFullDescribe =
            lp.contains('describe ')    || lp.contains('full schema') ||
            lp.contains('object info')  || lp.contains('schema of')  ||
            lp.contains('full info');
        if (!lp.contains('picklist') && asksFullDescribe && containsObjectName(lp)) {
            return describeObject(extractObjectName(prompt));
        }

        // ── PRIORITY 7 — Fields only (pure metadata) ──────────────────────────
        Boolean asksFieldsOnly =
            (lp.contains('all fields')        ||
             lp.contains('list fields')        ||
             lp.contains('show fields')        ||
             lp.contains('field list')         ||
             lp.contains('fields and their')   ||
             lp.contains('fields with their')  ||
             lp.contains('fields of the')      ||
             lp.contains('fields on the')      ||
             lp.contains('data types'))
            && !lp.contains('record')   && !lp.contains('fetch')
            && !lp.contains('get me')   && !lp.contains('retrieve')
            && !lp.contains('picklist') && !lp.contains('child')
            && !lp.contains('relationship');
        if (asksFieldsOnly && containsObjectName(lp)) {
            return getObjectFields(extractObjectName(prompt));
        }

        // ── PRIORITY 8 — OWD ──────────────────────────────────────────────────
        if (lp.contains('owd')              || lp.contains('org-wide')        ||
            lp.contains('org wide')         || lp.contains('sharing default') ||
            lp.contains('default sharing')  || lp.contains('sharing setting')) {
            return getOwdSettings();
        }

        // ── PRIORITY 9 — Permission Set detail OR list ────────────────────────
        if (lp.contains('permission set') && !lp.contains('group')) {
            if (wantsSpecificRecord(lp)) return getPermissionSetDetail(prompt);
            if (lp.contains('list') || lp.contains('all') ||
                lp.contains('show') || lp.contains('fetch'))
                return getPermissionSets();
        }

        // ── PRIORITY 10 — Permission Set Group detail OR list ─────────────────
        if (lp.contains('permission set group') || lp.contains('psg')) {
            if (wantsSpecificRecord(lp)) return getPermissionSetGroupDetail(prompt);
            if (lp.contains('list') || lp.contains('all') || lp.contains('show'))
                return getPermissionSetGroups();
        }

        // ── PRIORITY 11 — Profile detail OR list ──────────────────────────────
        if (lp.contains('profile')) {
            if (wantsSpecificRecord(lp)) return getProfileDetail(prompt);
            if (lp.contains('list') || lp.contains('all') || lp.contains('show'))
                return getProfiles();
        }

        // ── PRIORITY 12 — User Role detail OR list ────────────────────────────
        if (lp.contains('user role') || lp.contains('user roles') ||
            lp.contains('all roles') || lp.contains('list roles') ||
            lp.contains('show roles') ||
            (lp.contains('role') && (lp.contains('detail') || lp.contains('whose') ||
             lp.contains('named')    || lp.contains('called') ||
             lp.contains('information')))) {
            if (wantsSpecificRecord(lp) && !lp.contains('my'))
                return getUserRoleDetail(prompt);
            if ((lp.contains('list') || lp.contains('all') || lp.contains('show')) &&
                !lp.contains('my'))
                return getUserRoles();
        }

        // ── PRIORITY 13 — Custom objects ──────────────────────────────────────
        if ((lp.contains('custom object') || lp.contains('all object')) &&
            (lp.contains('list') || lp.contains('show') || lp.contains('all'))) {
            return listCustomObjects();
        }

        // ── PRIORITY 14 — Installed packages ──────────────────────────────────
        if (lp.contains('installed package') || lp.contains('managed package')) {
            return getInstalledPackages();
        }

        // ── PRIORITY 15 — Flow detail OR list ────────────────────────────────
        if (lp.contains('flow') && !lp.contains('soql') && !lp.contains('query')) {
            if (wantsSpecificRecord(lp)) return getFlowDetail(prompt);
            if (lp.contains('list') || lp.contains('all') || lp.contains('active'))
                return getFlows();
        }

        // ── PRIORITY 16 — Apex Class detail OR list ───────────────────────────
        if (lp.contains('apex class') || lp.contains('apex classes')) {
            if (wantsSpecificRecord(lp)) return getApexClassDetail(prompt);
            if (lp.contains('list') || lp.contains('all') || lp.contains('show'))
                return getApexClasses();
        }

        // ── PRIORITY 17 — Validation rules ───────────────────────────────────
        if (lp.contains('validation rule') &&
            (lp.contains('list') || lp.contains('show') || lp.contains('all') ||
             containsObjectName(lp))) {
            return getValidationRules(prompt);
        }

        // ── PRIORITY 18 — Record Type detail OR list ──────────────────────────
        if (lp.contains('record type')) {
            if (wantsSpecificRecord(lp)) return getRecordTypeDetail(prompt);
            if (lp.contains('list') || lp.contains('show') || lp.contains('all') ||
                containsObjectName(lp))
                return getRecordTypes(prompt);
        }

        // ── PRIORITY 19 — User detail OR list ────────────────────────────────
        if (lp.contains('user') && !lp.contains('my') &&
            !lp.contains('user role') && !lp.contains('username')) {
            if (wantsSpecificRecord(lp)) return getUserDetail(prompt);
            if (lp.contains('all user')   || lp.contains('list user') ||
                lp.contains('show user')  || lp.contains('active user'))
                return getActiveUsers();
        }

        return null;
    }

    // ══════════════════════════════════════════════════════════════════════════
    // ORG DATA METHODS
    // ══════════════════════════════════════════════════════════════════════════

    // ── Current user ──────────────────────────────────────────────────────────
    private static String getCurrentUserInfo() {
        User u = [
            SELECT Id, Name, Username, Email, Profile.Name,
                   UserRole.Name, IsActive, LastLoginDate
            FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1
        ];
        return '## 👤 Your Salesforce User\n\n'
             + '| Field | Value |\n|---|---|\n'
             + '| **Name** | '       + u.Name + ' |\n'
             + '| **Username** | `'  + u.Username + '` |\n'
             + '| **Email** | '      + u.Email + ' |\n'
             + '| **Profile** | '    + (u.Profile  != null ? u.Profile.Name  : '—') + ' |\n'
             + '| **Role** | '       + (u.UserRole != null ? u.UserRole.Name : '—') + ' |\n'
             + '| **Last Login** | ' + (u.LastLoginDate != null
                                        ? String.valueOf(u.LastLoginDate).substring(0,10)
                                        : 'Never') + ' |\n'
             + '| **Org ID** | `'    + UserInfo.getOrganizationId()   + '` |\n'
             + '| **Org Name** | '   + UserInfo.getOrganizationName() + ' |';
    }

    // ── Object fields only ────────────────────────────────────────────────────
    private static String getObjectFields(String objectName) {
        if (String.isBlank(objectName))
            return '❌ Please specify an object. Example: "Show fields on Contact"';
        try {
            Schema.SObjectType sot = Schema.getGlobalDescribe().get(objectName);
            if (sot == null) return '❌ Object `' + objectName + '` not found.';
            Schema.DescribeSObjectResult dsr = sot.getDescribe();
            Map<String, Schema.SObjectField> fields = dsr.fields.getMap();
            List<String> fns = new List<String>(fields.keySet());
            fns.sort();
            String result = '## 🗂 `' + dsr.getLabel() + '` — Fields (' + fields.size() + ')\n\n'
                          + '| # | Label | API Name | Type | Required |\n|---|---|---|---|---|\n';
            Integer idx = 1;
            for (String fn : fns) {
                Schema.DescribeFieldResult f = fields.get(fn).getDescribe();
                result += '| ' + idx++ + ' | ' + f.getLabel()
                        + ' | `' + f.getName() + '` | ' + f.getType()
                        + ' | ' + (f.isNillable() ? '' : '✅') + ' |\n';
            }
            return result;
        } catch (Exception e) { return '❌ Error: ' + e.getMessage(); }
    }

    // ── Object child relationships only ───────────────────────────────────────
    private static String getObjectChildren(String objectName) {
        if (String.isBlank(objectName))
            return '❌ Please specify an object. Example: "Show child objects of Account"';
        try {
            Schema.SObjectType sot = Schema.getGlobalDescribe().get(objectName);
            if (sot == null) return '❌ Object `' + objectName + '` not found.';
            Schema.DescribeSObjectResult dsr = sot.getDescribe();
            List<Schema.ChildRelationship> children = dsr.getChildRelationships();
            String result = '## 🔗 `' + dsr.getLabel()
                          + '` — Child Relationships (' + children.size() + ')\n\n'
                          + '| # | Child Object | Relationship Name | Field |\n|---|---|---|---|\n';
            Integer idx = 1;
            for (Schema.ChildRelationship cr : children) {
                if (cr.getRelationshipName() == null) continue;
                result += '| ' + idx++
                        + ' | `' + cr.getChildSObject().getDescribe().getName() + '`'
                        + ' | ' + cr.getRelationshipName()
                        + ' | `' + cr.getField().getDescribe().getName() + '` |\n';
            }
            return result;
        } catch (Exception e) { return '❌ Error: ' + e.getMessage(); }
    }

    // ── Full describe (fields + children) ─────────────────────────────────────
    private static String describeObject(String objectName) {
        if (String.isBlank(objectName))
            return '❌ Could not detect object name. Try: "describe Account"';
        try {
            Schema.SObjectType sot = Schema.getGlobalDescribe().get(objectName);
            if (sot == null) return '❌ Object `' + objectName + '` not found.';
            Schema.DescribeSObjectResult dsr    = sot.getDescribe();
            Map<String, Schema.SObjectField> fields   = dsr.fields.getMap();
            List<Schema.ChildRelationship>   children = dsr.getChildRelationships();
            String result = '## 🗂 `' + dsr.getLabel() + '` (`' + dsr.getName() + '`)\n\n'
                          + '**Total Fields:** ' + fields.size()
                          + '  ·  **Child Relationships:** ' + children.size() + '\n\n'
                          + '### Fields\n\n'
                          + '| # | Label | API Name | Type | Required |\n|---|---|---|---|---|\n';
            List<String> fns = new List<String>(fields.keySet());
            fns.sort();
            Integer idx = 1;
            for (String fn : fns) {
                Schema.DescribeFieldResult f = fields.get(fn).getDescribe();
                result += '| ' + idx++ + ' | ' + f.getLabel()
                        + ' | `' + f.getName() + '` | ' + f.getType()
                        + ' | ' + (f.isNillable() ? '' : '✅') + ' |\n';
            }
            result += '\n### Child Relationships\n\n'
                    + '| # | Child Object | Relationship Name | Field |\n|---|---|---|---|\n';
            Integer ci = 1;
            for (Schema.ChildRelationship cr : children) {
                if (cr.getRelationshipName() == null) continue;
                result += '| ' + ci++
                        + ' | `' + cr.getChildSObject().getDescribe().getName() + '`'
                        + ' | ' + cr.getRelationshipName()
                        + ' | `' + cr.getField().getDescribe().getName() + '` |\n';
            }
            return result;
        } catch (Exception e) { return '❌ Error describing object: ' + e.getMessage(); }
    }

    // ── OWD / Sharing ─────────────────────────────────────────────────────────
    private static String getOwdSettings() {
        try {
            List<String> objs = new List<String>{
                'Account','Contact','Opportunity','Lead','Case','Campaign',
                'Contract','Order','Asset','Quote','Task','Event','Product2'
            };
            String result = '## 🔒 Object Sharing Info\n\n'
                          + '| Object | Queryable | Createable | Has Share Object |\n|---|---|---|---|\n';
            Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
            for (String o : objs) {
                Schema.SObjectType sot = gd.get(o);
                if (sot == null) continue;
                Schema.DescribeSObjectResult dsr = sot.getDescribe();
                result += '| `' + o + '`'
                        + ' | ' + (dsr.isQueryable()  ? '✅' : '❌')
                        + ' | ' + (dsr.isCreateable() ? '✅' : '❌')
                        + ' | ' + (gd.containsKey(o + 'Share') ? '✅ `' + o + 'Share`' : '—') + ' |\n';
            }
            result += '\n> ℹ️ Full OWD values require Tooling API. Go to: **Setup → Sharing Settings**\n\n'
                    + 'Or in Developer Console with **Use Tooling API** checked:\n'
                    + '```soql\nSELECT SobjectType, InternalSharingModel, ExternalSharingModel\n'
                    + 'FROM OrganizationWideDefault ORDER BY SobjectType\n```';
            return result;
        } catch (Exception e) { return '❌ Error: ' + e.getMessage(); }
    }

    // ── Permission Sets (list) ────────────────────────────────────────────────
    private static String getPermissionSets() {
        List<PermissionSet> ps = [
            SELECT Id, Label, Name, IsCustom, CreatedDate
            FROM PermissionSet WHERE IsOwnedByProfile = false ORDER BY Label LIMIT 50
        ];
        if (ps.isEmpty()) return '📋 No custom permission sets found.';
        String r = '## 🛡 Permission Sets (' + ps.size() + ')\n\n'
                 + '| Label | API Name | Custom | Created |\n|---|---|---|---|\n';
        for (PermissionSet p : ps)
            r += '| **' + p.Label + '** | `' + p.Name + '` | '
               + (p.IsCustom ? '✅' : '—') + ' | '
               + String.valueOf(p.CreatedDate).substring(0,10) + ' |\n';
        return r;
    }

    // ── Permission Set (detail) ───────────────────────────────────────────────
    private static String getPermissionSetDetail(String prompt) {
        try {
            String searchName = extractQuotedOrKeywordValue(prompt);
            if (String.isBlank(searchName))
                return '❌ Please specify a name.\nExample: "Show details of permission set SF AI Agent User"';

            // Exact match first
            List<PermissionSet> exact = [
                SELECT Id, Label, Name, IsCustom, Description,
                       CreatedDate, LastModifiedDate, CreatedBy.Name, LastModifiedBy.Name,
                       PermissionsApiEnabled, PermissionsAuthorApex,
                       PermissionsCustomizeApplication, PermissionsManageUsers,
                       PermissionsModifyAllData, PermissionsViewAllData, License.Name
                FROM PermissionSet
                WHERE IsOwnedByProfile = false AND Name = :searchName LIMIT 1
            ];
            if (!exact.isEmpty()) return formatPermissionSetDetail(exact[0]);

            // LIKE partial
            List<PermissionSet> partial = [
                SELECT Id, Label, Name, IsCustom, Description,
                       CreatedDate, LastModifiedDate, CreatedBy.Name, LastModifiedBy.Name,
                       PermissionsApiEnabled, PermissionsAuthorApex,
                       PermissionsCustomizeApplication, PermissionsManageUsers,
                       PermissionsModifyAllData, PermissionsViewAllData, License.Name
                FROM PermissionSet
                WHERE IsOwnedByProfile = false
                  AND (Label LIKE :('%' + searchName + '%') OR Name LIKE :('%' + searchName + '%'))
                ORDER BY Label LIMIT 5
            ];
            if (partial.isEmpty())
                return '❌ No permission set found matching **"' + searchName + '"**.\n\nTry: "List all permission sets"';
            if (partial.size() == 1) return formatPermissionSetDetail(partial[0]);

            String t = '## 🛡 Multiple Matches for "' + searchName + '"\n\n| Label | API Name | Custom |\n|---|---|---|\n';
            for (PermissionSet p : partial)
                t += '| **' + p.Label + '** | `' + p.Name + '` | ' + (p.IsCustom ? '✅' : '—') + ' |\n';
            return t + '\n> Be more specific, e.g. "details of permission set ' + partial[0].Label + '"';
        } catch (Exception e) { return '❌ Error: ' + e.getMessage(); }
    }

    private static String formatPermissionSetDetail(PermissionSet ps) {
        return '## 🛡 Permission Set Detail\n\n'
             + '| Field | Value |\n|---|---|\n'
             + '| **Label** | '            + ps.Label + ' |\n'
             + '| **API Name** | `'         + ps.Name + '` |\n'
             + '| **Custom** | '            + (ps.IsCustom ? '✅ Yes' : '— No') + ' |\n'
             + '| **Description** | '       + (String.isNotBlank(ps.Description) ? ps.Description : '—') + ' |\n'
             + '| **License** | '           + (ps.License != null ? ps.License.Name : '—') + ' |\n'
             + '| **Created Date** | '      + String.valueOf(ps.CreatedDate).substring(0,10) + ' |\n'
             + '| **Created By** | '        + (ps.CreatedBy != null ? ps.CreatedBy.Name : '—') + ' |\n'
             + '| **Last Modified** | '     + String.valueOf(ps.LastModifiedDate).substring(0,10) + ' |\n'
             + '| **Last Modified By** | '  + (ps.LastModifiedBy != null ? ps.LastModifiedBy.Name : '—') + ' |\n'
             + '| **Record ID** | `'         + ps.Id + '` |\n\n'
             + '### Key Permissions\n\n| Permission | Enabled |\n|---|---|\n'
             + '| API Enabled | '               + (ps.PermissionsApiEnabled            ? '✅' : '❌') + ' |\n'
             + '| Author Apex | '               + (ps.PermissionsAuthorApex             ? '✅' : '❌') + ' |\n'
             + '| Customize Application | '     + (ps.PermissionsCustomizeApplication   ? '✅' : '❌') + ' |\n'
             + '| Manage Users | '              + (ps.PermissionsManageUsers            ? '✅' : '❌') + ' |\n'
             + '| Modify All Data | '           + (ps.PermissionsModifyAllData          ? '✅' : '❌') + ' |\n'
             + '| View All Data | '             + (ps.PermissionsViewAllData            ? '✅' : '❌') + ' |\n';
    }

    // ── Permission Set Groups (list) ──────────────────────────────────────────
    private static String getPermissionSetGroups() {
        List<PermissionSetGroup> psg = [
            SELECT Id, MasterLabel, DeveloperName, Status FROM PermissionSetGroup ORDER BY MasterLabel LIMIT 50
        ];
        if (psg.isEmpty()) return '📋 No permission set groups found.';
        String r = '## 🗂 Permission Set Groups (' + psg.size() + ')\n\n| Label | API Name | Status |\n|---|---|---|\n';
        for (PermissionSetGroup g : psg)
            r += '| **' + g.MasterLabel + '** | `' + g.DeveloperName + '` | ' + g.Status + ' |\n';
        return r;
    }

    // ── Permission Set Group (detail) ─────────────────────────────────────────
    private static String getPermissionSetGroupDetail(String prompt) {
        try {
            String searchName = extractQuotedOrKeywordValue(prompt);
            if (String.isBlank(searchName))
                return '❌ Please specify a name.\nExample: "Show details of permission set group Commerce_Shopper"';

            // Exact match first (by DeveloperName)
            List<PermissionSetGroup> exact = [
                SELECT Id, MasterLabel, DeveloperName, Description, Status,
                       CreatedDate, LastModifiedDate, CreatedBy.Name, LastModifiedBy.Name
                FROM PermissionSetGroup WHERE DeveloperName = :searchName LIMIT 1
            ];
            if (!exact.isEmpty()) return formatPSGDetail(exact[0]);

            // LIKE partial
            List<PermissionSetGroup> partial = [
                SELECT Id, MasterLabel, DeveloperName, Description, Status,
                       CreatedDate, LastModifiedDate, CreatedBy.Name, LastModifiedBy.Name
                FROM PermissionSetGroup
                WHERE MasterLabel   LIKE :('%' + searchName + '%')
                   OR DeveloperName LIKE :('%' + searchName + '%')
                ORDER BY MasterLabel LIMIT 5
            ];
            if (partial.isEmpty())
                return '❌ No permission set group found matching **"' + searchName + '"**.\n\nTry: "List all PS groups"';
            if (partial.size() == 1) return formatPSGDetail(partial[0]);

            String t = '## 🗂 Multiple Matches for "' + searchName + '"\n\n| Label | API Name | Status |\n|---|---|---|\n';
            for (PermissionSetGroup g : partial)
                t += '| **' + g.MasterLabel + '** | `' + g.DeveloperName + '` | ' + g.Status + ' |\n';
            return t + '\n> Be more specific, e.g. "details of PS group ' + partial[0].MasterLabel + '"';
        } catch (Exception e) { return '❌ Error: ' + e.getMessage(); }
    }

    private static String formatPSGDetail(PermissionSetGroup g) {
        List<PermissionSetGroupComponent> members = [
            SELECT PermissionSet.Label, PermissionSet.Name
            FROM PermissionSetGroupComponent WHERE PermissionSetGroupId = :g.Id LIMIT 20
        ];
        String r = '## 🗂 Permission Set Group Detail\n\n| Field | Value |\n|---|---|\n'
                 + '| **Label** | '            + g.MasterLabel + ' |\n'
                 + '| **API Name** | `'         + g.DeveloperName + '` |\n'
                 + '| **Status** | '           + g.Status + ' |\n'
                 + '| **Description** | '      + (String.isNotBlank(g.Description) ? g.Description : '—') + ' |\n'
                 + '| **Created Date** | '     + String.valueOf(g.CreatedDate).substring(0,10) + ' |\n'
                 + '| **Created By** | '       + (g.CreatedBy != null ? g.CreatedBy.Name : '—') + ' |\n'
                 + '| **Last Modified** | '    + String.valueOf(g.LastModifiedDate).substring(0,10) + ' |\n'
                 + '| **Last Modified By** | ' + (g.LastModifiedBy != null ? g.LastModifiedBy.Name : '—') + ' |\n'
                 + '| **Record ID** | `'        + g.Id + '` |\n';
        if (!members.isEmpty()) {
            r += '\n### Member Permission Sets (' + members.size() + ')\n\n| Label | API Name |\n|---|---|\n';
            for (PermissionSetGroupComponent m : members)
                r += '| ' + m.PermissionSet.Label + ' | `' + m.PermissionSet.Name + '` |\n';
        }
        return r;
    }

    // ── Profiles (list) ───────────────────────────────────────────────────────
    private static String getProfiles() {
        List<Profile> ps = [SELECT Id, Name, UserType FROM Profile ORDER BY Name LIMIT 50];
        String r = '## 👥 Profiles (' + ps.size() + ')\n\n| Name | User Type |\n|---|---|\n';
        for (Profile p : ps) r += '| **' + p.Name + '** | ' + p.UserType + ' |\n';
        return r;
    }

    // ── Profile (detail) ──────────────────────────────────────────────────────
    private static String getProfileDetail(String prompt) {
        try {
            String searchName = extractQuotedOrKeywordValue(prompt);
            if (String.isBlank(searchName))
                return '❌ Please specify a profile name.\nExample: "Show details of profile System Administrator"';

            List<Profile> exact = [
                SELECT Id, Name, UserType, Description, CreatedDate, LastModifiedDate,
                       CreatedBy.Name, LastModifiedBy.Name,
                       PermissionsApiEnabled, PermissionsAuthorApex,
                       PermissionsModifyAllData, PermissionsViewAllData,
                       PermissionsManageUsers, PermissionsCustomizeApplication
                FROM Profile WHERE Name = :searchName LIMIT 1
            ];
            if (!exact.isEmpty()) return formatProfileDetail(exact[0]);

            List<Profile> partial = [
                SELECT Id, Name, UserType, Description, CreatedDate, LastModifiedDate,
                       CreatedBy.Name, LastModifiedBy.Name,
                       PermissionsApiEnabled, PermissionsAuthorApex,
                       PermissionsModifyAllData, PermissionsViewAllData,
                       PermissionsManageUsers, PermissionsCustomizeApplication
                FROM Profile WHERE Name LIKE :('%' + searchName + '%') ORDER BY Name LIMIT 5
            ];
            if (partial.isEmpty())
                return '❌ No profile found matching **"' + searchName + '"**.\n\nTry: "List all profiles"';
            if (partial.size() == 1) return formatProfileDetail(partial[0]);

            String t = '## 👥 Multiple Matches for "' + searchName + '"\n\n| Name | User Type |\n|---|---|\n';
            for (Profile p : partial) t += '| **' + p.Name + '** | ' + p.UserType + ' |\n';
            return t + '\n> Be more specific, e.g. "details of profile ' + partial[0].Name + '"';
        } catch (Exception e) { return '❌ Error: ' + e.getMessage(); }
    }

    private static String formatProfileDetail(Profile p) {
        return '## 👥 Profile Detail\n\n| Field | Value |\n|---|---|\n'
             + '| **Name** | '              + p.Name + ' |\n'
             + '| **User Type** | '         + p.UserType + ' |\n'
             + '| **Description** | '       + (String.isNotBlank(p.Description) ? p.Description : '—') + ' |\n'
             + '| **Created Date** | '      + String.valueOf(p.CreatedDate).substring(0,10) + ' |\n'
             + '| **Created By** | '        + (p.CreatedBy != null ? p.CreatedBy.Name : '—') + ' |\n'
             + '| **Last Modified** | '     + String.valueOf(p.LastModifiedDate).substring(0,10) + ' |\n'
             + '| **Last Modified By** | '  + (p.LastModifiedBy != null ? p.LastModifiedBy.Name : '—') + ' |\n'
             + '| **Record ID** | `'         + p.Id + '` |\n\n'
             + '### Key Permissions\n\n| Permission | Enabled |\n|---|---|\n'
             + '| API Enabled | '               + (p.PermissionsApiEnabled            ? '✅' : '❌') + ' |\n'
             + '| Author Apex | '               + (p.PermissionsAuthorApex             ? '✅' : '❌') + ' |\n'
             + '| Customize Application | '     + (p.PermissionsCustomizeApplication   ? '✅' : '❌') + ' |\n'
             + '| Manage Users | '              + (p.PermissionsManageUsers            ? '✅' : '❌') + ' |\n'
             + '| Modify All Data | '           + (p.PermissionsModifyAllData          ? '✅' : '❌') + ' |\n'
             + '| View All Data | '             + (p.PermissionsViewAllData            ? '✅' : '❌') + ' |\n';
    }

    // ── User Roles (list) ─────────────────────────────────────────────────────
    private static String getUserRoles() {
        List<UserRole> roles = [SELECT Id, Name, DeveloperName, ParentRoleId FROM UserRole ORDER BY Name LIMIT 50];
        String r = '## 🏢 User Roles (' + roles.size() + ')\n\n| Name | API Name | Has Parent |\n|---|---|---|\n';
        for (UserRole u : roles)
            r += '| **' + u.Name + '** | `' + u.DeveloperName + '` | ' + (u.ParentRoleId != null ? '✅' : '') + ' |\n';
        return r;
    }

    // ── User Role (detail) ────────────────────────────────────────────────────
    private static String getUserRoleDetail(String prompt) {
        try {
            String searchName = extractQuotedOrKeywordValue(prompt);
            if (String.isBlank(searchName))
                return '❌ Please specify a role name.\nExample: "Show details of user role Recruiter"';

            List<UserRole> exact = [
                SELECT Id, Name, DeveloperName, ParentRoleId, ParentRole.Name, PortalType,
                       CaseAccessForAccountOwner, OpportunityAccessForAccountOwner,
                       ContactAccessForAccountOwner
                FROM UserRole WHERE Name = :searchName LIMIT 1
            ];
            if (!exact.isEmpty()) return formatUserRoleDetail(exact[0]);

            List<UserRole> partial = [
                SELECT Id, Name, DeveloperName, ParentRoleId, ParentRole.Name, PortalType,
                       CaseAccessForAccountOwner, OpportunityAccessForAccountOwner,
                       ContactAccessForAccountOwner
                FROM UserRole
                WHERE Name LIKE :('%' + searchName + '%') OR DeveloperName LIKE :('%' + searchName + '%')
                ORDER BY Name LIMIT 5
            ];
            if (partial.isEmpty())
                return '❌ No user role found matching **"' + searchName + '"**.\n\nTry: "Show all user roles"';
            if (partial.size() == 1) return formatUserRoleDetail(partial[0]);

            String t = '## 🏢 Multiple Matches for "' + searchName + '"\n\n| Name | API Name | Has Parent |\n|---|---|---|\n';
            for (UserRole r : partial)
                t += '| **' + r.Name + '** | `' + r.DeveloperName + '` | ' + (r.ParentRoleId != null ? '✅' : '—') + ' |\n';
            return t + '\n> Be more specific, e.g. "details of user role ' + partial[0].Name + '"';
        } catch (Exception e) { return '❌ Error: ' + e.getMessage(); }
    }

    private static String formatUserRoleDetail(UserRole r) {
        return '## 🏢 User Role Detail\n\n| Field | Value |\n|---|---|\n'
            + '| **Name** | '              + r.Name + ' |\n'
            + '| **API Name** | `'          + r.DeveloperName + '` |\n'
            + '| **Parent Role** | '        + (r.ParentRole != null ? r.ParentRole.Name : '— (Top Level)') + ' |\n'
            + '| **Portal Type** | '        + (String.isNotBlank(r.PortalType) ? r.PortalType : '—') + ' |\n'
            + '| **Case Access** | '        + (r.CaseAccessForAccountOwner    != null ? r.CaseAccessForAccountOwner    : '—') + ' |\n'
            + '| **Opp Access** | '         + (r.OpportunityAccessForAccountOwner != null ? r.OpportunityAccessForAccountOwner : '—') + ' |\n'
            + '| **Contact Access** | '     + (r.ContactAccessForAccountOwner  != null ? r.ContactAccessForAccountOwner  : '—') + ' |\n'
            + '| **Record ID** | `'          + r.Id + '` |\n';
    }

    // ── Active Users (list) ───────────────────────────────────────────────────
    private static String getActiveUsers() {
        List<User> users = [
            SELECT Id, Name, Username, Profile.Name, LastLoginDate
            FROM User WHERE IsActive = true ORDER BY Name LIMIT 50
        ];
        String r = '## 👥 Active Users (' + users.size() + ')\n\n| Name | Username | Profile | Last Login |\n|---|---|---|---|\n';
        for (User u : users)
            r += '| **' + u.Name + '** | `' + u.Username + '` | '
               + (u.Profile != null ? u.Profile.Name : '—') + ' | '
               + (u.LastLoginDate != null ? String.valueOf(u.LastLoginDate).substring(0,10) : 'Never') + ' |\n';
        return r;
    }

    // ── User (detail) ─────────────────────────────────────────────────────────
    private static String getUserDetail(String prompt) {
        try {
            String searchName = extractQuotedOrKeywordValue(prompt);
            if (String.isBlank(searchName))
                return '❌ Please specify a user name.\nExample: "Show details of user John Smith"';

            List<User> exact = [
                SELECT Id, Name, Username, Email, Phone, Profile.Name, UserRole.Name,
                       IsActive, LastLoginDate, CreatedDate, LanguageLocaleKey,
                       TimeZoneSidKey, Department, Title, CompanyName,
                       CreatedBy.Name, LastModifiedDate, LastModifiedBy.Name
                FROM User WHERE Name = :searchName AND IsActive = true LIMIT 1
            ];
            if (!exact.isEmpty()) return formatUserDetail(exact[0]);

            List<User> partial = [
                SELECT Id, Name, Username, Email, Phone, Profile.Name, UserRole.Name,
                       IsActive, LastLoginDate, CreatedDate, LanguageLocaleKey,
                       TimeZoneSidKey, Department, Title, CompanyName,
                       CreatedBy.Name, LastModifiedDate, LastModifiedBy.Name
                FROM User
                WHERE (Name LIKE :('%' + searchName + '%')
                   OR  Username LIKE :('%' + searchName + '%')
                   OR  Email    LIKE :('%' + searchName + '%'))
                  AND IsActive = true
                ORDER BY Name LIMIT 5
            ];
            if (partial.isEmpty())
                return '❌ No active user found matching **"' + searchName + '"**.\n\nTry: "Show all active users"';
            if (partial.size() == 1) return formatUserDetail(partial[0]);

            String t = '## 👤 Multiple Matches for "' + searchName + '"\n\n| Name | Username | Profile |\n|---|---|---|\n';
            for (User u : partial)
                t += '| **' + u.Name + '** | `' + u.Username + '` | ' + (u.Profile != null ? u.Profile.Name : '—') + ' |\n';
            return t + '\n> Be more specific, e.g. "details of user ' + partial[0].Name + '"';
        } catch (Exception e) { return '❌ Error: ' + e.getMessage(); }
    }

    private static String formatUserDetail(User u) {
        return '## 👤 User Detail\n\n| Field | Value |\n|---|---|\n'
             + '| **Name** | '             + u.Name + ' |\n'
             + '| **Username** | `'         + u.Username + '` |\n'
             + '| **Email** | '            + u.Email + ' |\n'
             + '| **Phone** | '            + (String.isNotBlank(u.Phone) ? u.Phone : '—') + ' |\n'
             + '| **Title** | '            + (String.isNotBlank(u.Title) ? u.Title : '—') + ' |\n'
             + '| **Department** | '       + (String.isNotBlank(u.Department) ? u.Department : '—') + ' |\n'
             + '| **Company** | '          + (String.isNotBlank(u.CompanyName) ? u.CompanyName : '—') + ' |\n'
             + '| **Profile** | '          + (u.Profile  != null ? u.Profile.Name  : '—') + ' |\n'
             + '| **Role** | '             + (u.UserRole != null ? u.UserRole.Name : '—') + ' |\n'
             + '| **Active** | '           + (u.IsActive ? '✅ Yes' : '❌ No') + ' |\n'
             + '| **Last Login** | '       + (u.LastLoginDate != null ? String.valueOf(u.LastLoginDate).substring(0,10) : 'Never') + ' |\n'
             + '| **Language** | '         + (String.isNotBlank(u.LanguageLocaleKey) ? u.LanguageLocaleKey : '—') + ' |\n'
             + '| **Timezone** | '         + (String.isNotBlank(u.TimeZoneSidKey) ? u.TimeZoneSidKey : '—') + ' |\n'
             + '| **Created Date** | '     + String.valueOf(u.CreatedDate).substring(0,10) + ' |\n'
             + '| **Created By** | '       + (u.CreatedBy != null ? u.CreatedBy.Name : '—') + ' |\n'
             + '| **Last Modified** | '    + String.valueOf(u.LastModifiedDate).substring(0,10) + ' |\n'
             + '| **Last Modified By** | ' + (u.LastModifiedBy != null ? u.LastModifiedBy.Name : '—') + ' |\n'
             + '| **Record ID** | `'        + u.Id + '` |\n';
    }

    // ── Flows (list) ──────────────────────────────────────────────────────────
    private static String getFlows() {
        try {
            List<FlowDefinitionView> flows = [
                SELECT ApiName, Label, ProcessType, IsActive FROM FlowDefinitionView LIMIT 200
            ];
            if (flows.isEmpty()) return '📋 No flows found.';
            String r = '## ⚡ Flows (' + flows.size() + ')\n\n| Label | API Name | Type | Active |\n|---|---|---|---|\n';
            for (FlowDefinitionView f : flows)
                r += '| **' + (f.Label != null ? f.Label : '—') + '**'
                   + ' | `' + (f.ApiName != null ? f.ApiName : '—') + '`'
                   + ' | ' + (f.ProcessType != null ? f.ProcessType : '—')
                   + ' | ' + (f.IsActive ? '✅' : '❌') + ' |\n';
            return r;
        } catch (Exception e) { return '❌ Error fetching flows: ' + e.getMessage(); }
    }

    // ── Flow (detail) ─────────────────────────────────────────────────────────
    private static String getFlowDetail(String prompt) {
        try {
            String searchName = extractQuotedOrKeywordValue(prompt);
            if (String.isBlank(searchName))
                return '❌ Please specify a flow name.\nExample: "Show details of flow MyFlow"';

            // FlowDefinitionView does NOT support OR — two separate queries
            List<FlowDefinitionView> byLabel = new List<FlowDefinitionView>();
            List<FlowDefinitionView> byApi   = new List<FlowDefinitionView>();
            try {
                byLabel = [SELECT ApiName, Label, ProcessType, TriggerType, IsActive, Description, LastModifiedDate
                           FROM FlowDefinitionView WHERE Label = :searchName LIMIT 1];
            } catch (Exception e1) { }
            if (byLabel.isEmpty()) {
                try {
                    byLabel = [SELECT ApiName, Label, ProcessType, TriggerType, IsActive, Description, LastModifiedDate
                               FROM FlowDefinitionView WHERE Label LIKE :('%' + searchName + '%') LIMIT 5];
                } catch (Exception e2) { }
            }
            try {
                byApi = [SELECT ApiName, Label, ProcessType, TriggerType, IsActive, Description, LastModifiedDate
                         FROM FlowDefinitionView WHERE ApiName LIKE :('%' + searchName + '%') LIMIT 5];
            } catch (Exception e3) { }

            Map<String, FlowDefinitionView> merged = new Map<String, FlowDefinitionView>();
            for (FlowDefinitionView f : byLabel) { if (f != null && f.ApiName != null) merged.put(f.ApiName, f); }
            for (FlowDefinitionView f : byApi)   { if (f != null && f.ApiName != null) merged.put(f.ApiName, f); }

            if (merged.isEmpty())
                return '❌ No flow found matching **"' + searchName + '"**.\n\nTry: "List all active flows"';

            List<FlowDefinitionView> results = new List<FlowDefinitionView>(merged.values());
            if (results.size() == 1) return formatFlowDetail(results[0]);

            String t = '## ⚡ Multiple Matches for "' + searchName + '"\n\n| Label | API Name | Active |\n|---|---|---|\n';
            for (FlowDefinitionView f : results)
                t += '| **' + (f.Label != null ? f.Label : '—') + '** | `'
                   + (f.ApiName != null ? f.ApiName : '—') + '` | ' + (f.IsActive ? '✅' : '❌') + ' |\n';
            return t + '\n> Be more specific, e.g. "details of flow ' + results[0].Label + '"';
        } catch (Exception e) { return '❌ Error fetching flow: ' + e.getMessage(); }
    }

    private static String formatFlowDetail(FlowDefinitionView f) {
        return '## ⚡ Flow Detail\n\n| Field | Value |\n|---|---|\n'
             + '| **Label** | '         + (f.Label       != null ? f.Label       : '—') + ' |\n'
             + '| **API Name** | `'      + (f.ApiName     != null ? f.ApiName     : '—') + '` |\n'
             + '| **Process Type** | '  + (f.ProcessType != null ? f.ProcessType : '—') + ' |\n'
             + '| **Trigger Type** | '  + (f.TriggerType != null ? f.TriggerType : '—') + ' |\n'
             + '| **Active** | '        + (f.IsActive ? '✅ Yes' : '❌ No') + ' |\n'
             + '| **Description** | '   + (String.isNotBlank(f.Description) ? f.Description : '—') + ' |\n'
             + '| **Last Modified** | ' + (f.LastModifiedDate != null
                                           ? String.valueOf(f.LastModifiedDate).substring(0,10) : '—') + ' |\n';
    }

    // ── Apex Classes (list) ───────────────────────────────────────────────────
    private static String getApexClasses() {
        List<ApexClass> classes = [SELECT Id, Name, Status, IsValid, LastModifiedDate FROM ApexClass ORDER BY Name LIMIT 100];
        String r = '## ⚙️ Apex Classes (' + classes.size() + ')\n\n| Name | Status | Valid | Last Modified |\n|---|---|---|---|\n';
        for (ApexClass c : classes)
            r += '| `' + c.Name + '` | ' + c.Status + ' | '
               + (c.IsValid ? '✅' : '❌') + ' | '
               + String.valueOf(c.LastModifiedDate).substring(0,10) + ' |\n';
        return r;
    }

    // ── Apex Class (detail) ───────────────────────────────────────────────────
    private static String getApexClassDetail(String prompt) {
        try {
            String searchName = extractQuotedOrKeywordValue(prompt);
            if (String.isBlank(searchName))
                return '❌ Please specify a class name.\nExample: "Show details of Apex class SfAiAgentController"';

            // Exact match first
            List<ApexClass> exact = [
                SELECT Id, Name, Status, IsValid, ApiVersion, LengthWithoutComments, Body,
                       CreatedDate, LastModifiedDate, CreatedBy.Name, LastModifiedBy.Name, NamespacePrefix
                FROM ApexClass WHERE Name = :searchName LIMIT 1
            ];
            if (!exact.isEmpty()) return formatApexClassDetail(exact[0]);

            // LIKE partial
            List<ApexClass> partial = [
                SELECT Id, Name, Status, IsValid, ApiVersion, LengthWithoutComments, Body,
                       CreatedDate, LastModifiedDate, CreatedBy.Name, LastModifiedBy.Name, NamespacePrefix
                FROM ApexClass WHERE Name LIKE :('%' + searchName + '%') ORDER BY Name LIMIT 5
            ];
            if (partial.isEmpty())
                return '❌ No Apex class found matching **"' + searchName + '"**.\n\nTry: "List all Apex classes"';
            if (partial.size() == 1) return formatApexClassDetail(partial[0]);

            String t = '## ⚙️ Multiple Matches for "' + searchName + '"\n\n| Name | Status | Valid |\n|---|---|---|\n';
            for (ApexClass c : partial)
                t += '| `' + c.Name + '` | ' + c.Status + ' | ' + (c.IsValid ? '✅' : '❌') + ' |\n';
            return t + '\n> Please be more specific. Example: "details of Apex class ' + partial[0].Name + '"';
        } catch (Exception e) { return '❌ Error fetching Apex class: ' + e.getMessage(); }
    }

    private static String formatApexClassDetail(ApexClass c) {
        Integer lineCount = String.isNotBlank(c.Body) ? c.Body.split('\n').size() : 0;
        return '## ⚙️ Apex Class Detail\n\n| Field | Value |\n|---|---|\n'
             + '| **Name** | `'               + c.Name + '` |\n'
             + '| **Status** | '              + c.Status + ' |\n'
             + '| **Is Valid** | '            + (c.IsValid ? '✅ Yes' : '❌ No') + ' |\n'
             + '| **API Version** | '         + c.ApiVersion + ' |\n'
             + '| **Namespace** | '           + (String.isNotBlank(c.NamespacePrefix) ? '`' + c.NamespacePrefix + '`' : '— (no namespace)') + ' |\n'
             + '| **Lines of Code** | '       + lineCount + ' |\n'
             + '| **Chars (no comments)** | ' + c.LengthWithoutComments + ' |\n'
             + '| **Created Date** | '        + String.valueOf(c.CreatedDate).substring(0,10) + ' |\n'
             + '| **Created By** | '          + (c.CreatedBy != null ? c.CreatedBy.Name : '—') + ' |\n'
             + '| **Last Modified** | '       + String.valueOf(c.LastModifiedDate).substring(0,10) + ' |\n'
             + '| **Last Modified By** | '    + (c.LastModifiedBy != null ? c.LastModifiedBy.Name : '—') + ' |\n'
             + '| **Record ID** | `'           + c.Id + '` |\n';
    }

    // ── Picklist VALUES ───────────────────────────────────────────────────────
    private static String getPicklistValues(String prompt) {
        String objectName = extractObjectName(prompt);
        String fieldName  = extractFieldName(prompt);
        if (String.isBlank(objectName) || String.isBlank(fieldName))
            return '❌ Please specify both object and field.\nExample: "Show picklist values for Account.Industry"';
        try {
            Schema.SObjectType sot = Schema.getGlobalDescribe().get(objectName);
            if (sot == null) return '❌ Object `' + objectName + '` not found.';
            Schema.SObjectField fld = sot.getDescribe().fields.getMap().get(fieldName);
            if (fld == null) return '❌ Field `' + fieldName + '` not found on `' + objectName + '`.';
            List<Schema.PicklistEntry> entries = fld.getDescribe().getPicklistValues();
            if (entries.isEmpty()) return '⚠️ `' + fieldName + '` has no picklist values or is not a picklist.';
            String r = '## 🎨 Picklist: `' + objectName + '.' + fieldName + '`\n\n**Total:** '
                     + entries.size() + ' values\n\n| Label | API Value | Active | Default |\n|---|---|---|---|\n';
            for (Schema.PicklistEntry e : entries)
                r += '| ' + e.getLabel() + ' | `' + e.getValue() + '` | '
                   + (e.isActive() ? '✅' : '❌') + ' | ' + (e.isDefaultValue() ? '⭐' : '') + ' |\n';
            return r;
        } catch (Exception e) { return '❌ Error: ' + e.getMessage(); }
    }

    // ── Picklist FIELDS ───────────────────────────────────────────────────────
    private static String getPicklistFields(String prompt) {
        String objectName = extractObjectName(prompt);
        if (String.isBlank(objectName))
            return '❌ Please specify an object. Example: "Show picklist fields on Account"';
        try {
            Schema.SObjectType sot = Schema.getGlobalDescribe().get(objectName);
            if (sot == null) return '❌ Object `' + objectName + '` not found.';
            Map<String, Schema.SObjectField> allFields = sot.getDescribe().fields.getMap();
            List<String> picklistFns = new List<String>();
            for (String fn : allFields.keySet()) {
                Schema.DescribeFieldResult dfr = allFields.get(fn).getDescribe();
                if (dfr.getType() == Schema.DisplayType.PICKLIST ||
                    dfr.getType() == Schema.DisplayType.MULTIPICKLIST)
                    picklistFns.add(fn);
            }
            if (picklistFns.isEmpty()) return '📋 No picklist fields found on `' + objectName + '`.';
            picklistFns.sort();
            String r = '## 🎨 Picklist Fields — `' + objectName + '` (' + picklistFns.size() + ')\n\n'
                     + '| Field Label | API Name | Type |\n|---|---|---|\n';
            for (String fn : picklistFns) {
                Schema.DescribeFieldResult dfr = allFields.get(fn).getDescribe();
                r += '| ' + dfr.getLabel() + ' | `' + fn + '` | ' + dfr.getType() + ' |\n';
            }
            return r;
        } catch (Exception e) { return '❌ Error: ' + e.getMessage(); }
    }

    // ── Custom Objects ────────────────────────────────────────────────────────
    private static String listCustomObjects() {
        List<EntityDefinition> objs = [
            SELECT QualifiedApiName, Label FROM EntityDefinition
            WHERE QualifiedApiName LIKE '%__c' AND IsDeprecatedAndHidden = false
            ORDER BY QualifiedApiName LIMIT 100
        ];
        if (objs.isEmpty()) return '📋 No custom objects found.';
        String r = '## 📦 Custom Objects (' + objs.size() + ')\n\n| Label | API Name |\n|---|---|\n';
        for (EntityDefinition o : objs) r += '| ' + o.Label + ' | `' + o.QualifiedApiName + '` |\n';
        return r;
    }

    // ── Installed Packages ────────────────────────────────────────────────────
    private static String getInstalledPackages() {
        List<PackageLicense> pkgs = [SELECT AllowedLicenses, UsedLicenses, ExpirationDate, NamespacePrefix FROM PackageLicense ORDER BY NamespacePrefix];
        if (pkgs.isEmpty()) return '📋 No installed managed packages found.';
        String r = '## 📦 Installed Packages (' + pkgs.size() + ')\n\n| Namespace | Used | Allowed | Expires |\n|---|---|---|---|\n';
        for (PackageLicense p : pkgs)
            r += '| `' + p.NamespacePrefix + '` | ' + p.UsedLicenses + ' | ' + p.AllowedLicenses
               + ' | ' + (p.ExpirationDate != null ? String.valueOf(p.ExpirationDate) : 'Never') + ' |\n';
        return r;
    }

    // ── Validation Rules ──────────────────────────────────────────────────────
    private static String getValidationRules(String prompt) {
        String objectName = extractObjectName(prompt);
        String q = 'SELECT Id, ValidationName, Active, ErrorMessage, EntityDefinition.QualifiedApiName\n'
                 + 'FROM ValidationRule\n'
                 + (String.isNotBlank(objectName) ? 'WHERE EntityDefinition.QualifiedApiName = \'' + objectName + '\'\n' : '')
                 + 'ORDER BY ValidationName';
        return '## ✅ Validation Rules' + (String.isNotBlank(objectName) ? ' — `' + objectName + '`' : '') + '\n\n'
             + '> ⚠️ **Validation Rules require Tooling API** — not queryable via standard SOQL.\n\n'
             + '**Option 1 — Setup UI:** Setup → Object Manager → **'
             + (String.isNotBlank(objectName) ? objectName : 'Your Object') + '** → Validation Rules\n\n'
             + '**Option 2 — Developer Console:**\n1. Open Developer Console → Query Editor\n'
             + '2. ✅ Check **"Use Tooling API"**\n3. Run:\n\n```soql\n' + q + '\n```\n\n'
             + '**Option 3 — REST API:**\n```\nGET /services/data/v59.0/tooling/query/?q='
             + EncodingUtil.urlEncode(q.replaceAll('\n', ' '), 'UTF-8') + '\n```';
    }

    // ── Record Types (list) ───────────────────────────────────────────────────
    private static String getRecordTypes(String prompt) {
        String objectName = extractObjectName(prompt);
        String soql = 'SELECT Id, Name, DeveloperName, SobjectType, IsActive FROM RecordType';
        if (String.isNotBlank(objectName))
            soql += ' WHERE SobjectType = \'' + String.escapeSingleQuotes(objectName) + '\'';
        soql += ' ORDER BY SobjectType, Name LIMIT 100';
        List<RecordType> rts = Database.query(soql);
        if (rts.isEmpty())
            return '📋 No record types found' + (String.isNotBlank(objectName) ? ' for `' + objectName + '`' : '') + '.';
        String r = '## 📋 Record Types (' + rts.size() + ')\n\n| Name | API Name | Object | Active |\n|---|---|---|---|\n';
        for (RecordType rt : rts)
            r += '| **' + rt.Name + '** | `' + rt.DeveloperName + '` | ' + rt.SobjectType + ' | ' + (rt.IsActive ? '✅' : '❌') + ' |\n';
        return r;
    }

    // ── Record Type (detail) ──────────────────────────────────────────────────
    private static String getRecordTypeDetail(String prompt) {
        try {
            String searchName = extractQuotedOrKeywordValue(prompt);
            String objectName = extractObjectName(prompt);
            if (String.isBlank(searchName) && String.isBlank(objectName))
                return '❌ Please specify a record type name.\nExample: "Show details of record type Retail for Account"';

            List<String> conditions = new List<String>();
            if (String.isNotBlank(searchName)) {
                conditions.add('(Name LIKE \'%' + String.escapeSingleQuotes(searchName) + '%\' '
                             + 'OR DeveloperName LIKE \'%' + String.escapeSingleQuotes(searchName) + '%\')');
            }
            if (String.isNotBlank(objectName))
                conditions.add('SobjectType = \'' + String.escapeSingleQuotes(objectName) + '\'');

            String soql = 'SELECT Id, Name, DeveloperName, SobjectType, IsActive, Description, '
                        + 'CreatedDate, LastModifiedDate, CreatedBy.Name, LastModifiedBy.Name '
                        + 'FROM RecordType WHERE ' + String.join(conditions, ' AND ') + ' ORDER BY Name LIMIT 5';
            List<RecordType> results = Database.query(soql);

            if (results.isEmpty())
                return '❌ No record type found matching your criteria.\n\nTry: "Show all record types" or "Show record types for Account"';
            if (results.size() == 1) return formatRecordTypeDetail(results[0]);

            String t = '## 📋 Multiple Matches\n\n| Name | API Name | Object | Active |\n|---|---|---|---|\n';
            for (RecordType rt : results)
                t += '| **' + rt.Name + '** | `' + rt.DeveloperName + '` | ' + rt.SobjectType + ' | ' + (rt.IsActive ? '✅' : '❌') + ' |\n';
            return t + '\n> Be more specific, e.g. "details of record type ' + results[0].Name + '"';
        } catch (Exception e) { return '❌ Error: ' + e.getMessage(); }
    }

    private static String formatRecordTypeDetail(RecordType rt) {
        return '## 📋 Record Type Detail\n\n| Field | Value |\n|---|---|\n'
             + '| **Name** | '             + rt.Name + ' |\n'
             + '| **API Name** | `'          + rt.DeveloperName + '` |\n'
             + '| **Object** | '            + rt.SobjectType + ' |\n'
             + '| **Active** | '            + (rt.IsActive ? '✅ Yes' : '❌ No') + ' |\n'
             + '| **Description** | '       + (String.isNotBlank(rt.Description) ? rt.Description : '—') + ' |\n'
             + '| **Created Date** | '      + String.valueOf(rt.CreatedDate).substring(0,10) + ' |\n'
             + '| **Created By** | '        + (rt.CreatedBy != null ? rt.CreatedBy.Name : '—') + ' |\n'
             + '| **Last Modified** | '     + String.valueOf(rt.LastModifiedDate).substring(0,10) + ' |\n'
             + '| **Last Modified By** | '  + (rt.LastModifiedBy != null ? rt.LastModifiedBy.Name : '—') + ' |\n'
             + '| **Record ID** | `'         + rt.Id + '` |\n';
    }

    // ══════════════════════════════════════════════════════════════════════════
    // SOQL EXECUTION
    // ══════════════════════════════════════════════════════════════════════════

    private static String executeSoqlAndFormat(String query) {
        try {
            String lower = query.trim().toLowerCase();

            // Tooling API guard
            for (String toolingObj : TOOLING_ONLY_OBJECTS) {
                if (lower.contains('from ' + toolingObj)) {
                    String disp = toolingObj.substring(0,1).toUpperCase() + toolingObj.substring(1);
                    return '## ⚠️ Tooling API Object\n\n`' + disp + '` cannot be queried via standard SOQL.\n\n'
                         + '**Run in Developer Console:**\n1. Open Developer Console → Query Editor\n'
                         + '2. ✅ Check **"Use Tooling API"**\n3. Paste and run:\n\n```soql\n' + query + '\n```';
                }
            }

            // COUNT
            if (lower.startsWith('select count(')) {
                Integer total = Database.countQuery(query);
                return '## 📊 Count Result\n\n```soql\n' + query + '\n```\n\n**Total Records:** ' + total;
            }

            // Subquery detection
            Boolean hasSubquery = query.indexOf('(') > 0
                && query.indexOf('(') < query.lastIndexOf(')')
                && lower.contains('select')
                && lower.indexOf('select') != lower.lastIndexOf('select');
            if (hasSubquery) return executeSubqueryAndFormat(query);

            // Standard flat query
            List<SObject> records = Database.query(query);
            if (records.isEmpty())
                return '## 🔍 No Records Found\n\n```soql\n' + query + '\n```\n\n*No records matched your criteria.*';

            List<String> lines = new List<String>();
            lines.add('## 📋 Query Results\n\n```soql\n' + query + '\n```\n');
            lines.add('**Total: ' + records.size() + ' record(s)**\n');

            Map<String, Object> first = records[0].getPopulatedFieldsAsMap();
            List<String> fns = new List<String>(first.keySet());
            String header = '| '; String sep = '|';
            for (String fn : fns) { header += fn + ' | '; sep += '---|'; }
            lines.add(header); lines.add(sep);

            for (Integer i = 0; i < records.size(); i++) {
                String row = '| ';
                for (String fn : fns) row += formatFieldValue(records[i].get(fn)) + ' | ';
                lines.add(row);
            }
            return String.join(lines, '\n');

        } catch (Exception e) {
            String errMsg = e.getMessage() != null ? e.getMessage() : 'Unknown error';

            // Invalid field → show valid fields
            if (errMsg.contains('No such column') || errMsg.contains('no such column')) {
                String objectName = extractObjectNameFromQuery(query);
                String fieldHelp  = '';
                if (String.isNotBlank(objectName)) {
                    try {
                        Schema.SObjectType sot = Schema.getGlobalDescribe().get(objectName);
                        if (sot != null) {
                            Map<String, Schema.SObjectField> fields = sot.getDescribe().fields.getMap();
                            List<String> fns = new List<String>(fields.keySet());
                            fns.sort();
                            fieldHelp = '\n\n### ✅ Valid fields on `' + objectName + '`\n\n| API Name | Label | Type |\n|---|---|---|\n';
                            for (String fn : fns) {
                                Schema.DescribeFieldResult f = fields.get(fn).getDescribe();
                                fieldHelp += '| `' + f.getName() + '` | ' + f.getLabel() + ' | ' + f.getType() + ' |\n';
                            }
                        }
                    } catch (Exception de) { fieldHelp = '\n\n*Could not retrieve field list.*'; }
                }
                return '## ❌ Invalid Field\n\n' + errMsg + '\n\n'
                     + '**Fix:** Check the field API name — it may be misspelled or not exist on this object.\n\n'
                     + '```soql\n' + query + '\n```' + fieldHelp;
            }

            // Tooling API
            if (errMsg.contains('is not supported')) {
                return '## ⚠️ Unsupported Object\n\n❌ ' + errMsg + '\n\n'
                     + 'This object requires **Tooling API**.\n\n'
                     + '**Run in Developer Console:**\n1. Open Developer Console → Query Editor\n'
                     + '2. ✅ Check **"Use Tooling API"**\n3. Run:\n\n```soql\n' + query + '\n```';
            }

            return '❌ **SOQL Error:** ' + errMsg + '\n\n```soql\n' + query + '\n```';
        }
    }

    private static String executeSubqueryAndFormat(String query) {
        try {
            List<SObject> parentRecords = Database.query(query);
            if (parentRecords.isEmpty())
                return '## 🔍 No Records Found\n\n```soql\n' + query + '\n```\n\n*No parent records matched.*';

            List<String> lines = new List<String>();
            lines.add('## 📋 Query Results\n\n```soql\n' + query + '\n```\n');
            lines.add('**' + parentRecords.size() + ' parent record(s) found**\n');

            for (SObject parent : parentRecords) {
                Map<String, Object> pfm = parent.getPopulatedFieldsAsMap();
                String parentRow = '';
                for (String fn : pfm.keySet()) {
                    if (fn == 'attributes') continue;
                    try {
                        if (pfm.get(fn) instanceof List<SObject>) continue;
                        parentRow += '**' + fn + ':** `' + formatFieldValue(pfm.get(fn)) + '`   ';
                    } catch (Exception skip) { continue; }
                }
                lines.add('### 🔹 ' + parentRow.trim());

                for (String fn : pfm.keySet()) {
                    Object rawVal = pfm.get(fn);
                    if (!(rawVal instanceof List<SObject>)) continue;
                    List<SObject> children = (List<SObject>) rawVal;
                    lines.add('\n**↳ ' + fn + '** — ' + children.size() + ' child record(s)\n');
                    if (children.isEmpty()) { lines.add('*No child records found.*\n'); continue; }

                    Set<String> cfs = children[0].getPopulatedFieldsAsMap().keySet();
                    List<String> childFields = new List<String>();
                    for (String cf : cfs) {
                        if (cf == 'attributes') continue;
                        try { Object p = children[0].get(cf); childFields.add(cf); }
                        catch (SObjectException ex) { }
                    }
                    if (childFields.isEmpty()) { lines.add('*Could not read child fields.*\n'); continue; }

                    String hdr = '| '; String sep = '|';
                    for (String cf : childFields) { hdr += cf + ' | '; sep += '---|'; }
                    lines.add(hdr); lines.add(sep);

                    for (Integer i = 0; i < children.size(); i++) {
                        String row = '| ';
                        for (String cf : childFields) {
                            String cv = '';
                            try { cv = formatFieldValue(children[i].get(cf)); }
                            catch (SObjectException ex) { cv = '—'; }
                            row += cv + ' | ';
                        }
                        lines.add(row);
                    }
                    lines.add('');
                }
                lines.add('\n---\n');
            }
            return String.join(lines, '\n');
        } catch (Exception e) {
            return '❌ **Subquery Error:** ' + e.getMessage()
                 + '\n\n```soql\n' + query + '\n```\n\n'
                 + '💡 Try running directly in Developer Console → Query Editor.';
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // OPENAI HELPERS
    // ══════════════════════════════════════════════════════════════════════════

    private static String generateSoqlQuery(String prompt) {
        String sp = getSoqlSystemPrompt();
        return stripCodeFences(callOpenAI(sp, prompt, 400, 0.0)).trim();
    }

    private static String callOpenAIChat(String prompt) {
        return callOpenAI(getSystemPrompt(), prompt, 1500, 0.2);
    }

private static String callOpenAI(String systemPrompt, String userPrompt,
                                  Integer maxTokens, Decimal temperature) {
    List<Map<String, String>> msgs = new List<Map<String, String>>();
    msgs.add(new Map<String, String>{'role' => 'system', 'content' => systemPrompt});
    msgs.add(new Map<String, String>{'role' => 'user',   'content' => userPrompt});

    Map<String, Object> body = new Map<String, Object>();
    body.put('model',       'gpt-4o-mini');
    body.put('max_tokens',  maxTokens);
    body.put('temperature', temperature);
    body.put('messages',    msgs);

    HttpRequest req = new HttpRequest();
    req.setEndpoint('callout:OpenAI_API/chat/completions');          // ← изменено
    req.setMethod('POST');
    req.setHeader('Content-Type', 'application/json');
    req.setHeader('Authorization', 'Bearer {!$Credential.OpenAI_API.apiKey}'); // ← изменено
    req.setTimeout(120000);
    req.setBody(JSON.serialize(body));

    HttpResponse res = new Http().send(req);
    if (res.getStatusCode() != 200)
        throw new AuraHandledException('OpenAI error (' + res.getStatusCode() + '): ' + res.getBody());

    Map<String, Object> resp = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    List<Object> choices = (List<Object>) resp.get('choices');
    if (choices == null || choices.isEmpty())
        throw new AuraHandledException('No choices returned from OpenAI.');

    Map<String, Object> msg = (Map<String, Object>) ((Map<String, Object>) choices[0]).get('message');
    if (msg == null) throw new AuraHandledException('Null message from OpenAI.');
    return (String) msg.get('content');
}

    // ══════════════════════════════════════════════════════════════════════════
    // UTILITIES
    // ══════════════════════════════════════════════════════════════════════════

    private static Boolean containsObjectName(String lp) {
        return lp.contains('account')     || lp.contains('contact')      ||
               lp.contains('opportunity') || lp.contains('lead')         ||
               lp.contains('case')        || lp.contains('task')         ||
               lp.contains('event')       || lp.contains('user')         ||
               lp.contains('contract')    || lp.contains('order')        ||
               lp.contains('product')     || lp.contains('asset')        ||
               lp.contains('campaign')    || lp.contains('quote')        ||
               lp.contains('fan')         || lp.contains('purchase order')||
               lp.contains('ticket')      || lp.contains('sport event')  ||
               lp.contains('team')        || lp.contains('stadium')      ||
               lp.contains('season pass') || lp.contains('loyalty transaction') ||
               lp.contains('__c');
    }

    private static String extractObjectName(String prompt) {
        String lp = prompt.toLowerCase();
        List<String> stdObjects = new List<String>{
            'account','contact','opportunity','lead','case','task','event',
            'user','contract','order','product2','asset','campaign','quote','pricebook2',
            'fan__c','purchase_order__c','ticket__c','sport_event__c','team__c',
            'stadium__c','stadium_section__c','season_pass__c','loyalty_transaction__c'
        };
        for (String o : stdObjects) {
            if (lp.contains(o)) return o;
        }
        Pattern p = Pattern.compile('\\b([A-Za-z][A-Za-z0-9_]*__c)\\b');
        Matcher m = p.matcher(prompt);
        if (m.find()) return m.group(1);
        return null;
    }

    private static String extractFieldName(String prompt) {
        Pattern dotPat = Pattern.compile('[A-Za-z][A-Za-z0-9_]*\\.([A-Za-z][A-Za-z0-9_]*(?:__c)?)');
        Matcher dotM = dotPat.matcher(prompt);
        if (dotM.find()) return dotM.group(1);
        String lp = prompt.toLowerCase();
        for (String kw : new List<String>{'for field ','field ','picklist ','of field ','values of ','values for '}) {
            Integer idx = lp.indexOf(kw);
            if (idx >= 0) {
                String rest = prompt.substring(idx + kw.length()).trim().split(' ')[0].replaceAll('[^A-Za-z0-9_]','');
                if (String.isNotBlank(rest)) return rest;
            }
        }
        return null;
    }

    private static String extractQuotedOrKeywordValue(String prompt) {
        // Step 1 — Quoted value wins always
        Pattern quoted = Pattern.compile('["\']([^"\']+)["\']');
        Matcher qm = quoted.matcher(prompt);
        if (qm.find()) return qm.group(1).trim();

        // Step 2 — Specific multi-word keyword phrases (safe to take full remainder)
        String lp = prompt.toLowerCase();
        List<String> specificKeywords = new List<String>{
            'name equals ','name = ','whose name is ','whose name ',
            'named ','called ','label equals ','label = ',
            'full detail of ','full details of ',
            'detail of ','details of ','detail for ','details for ',
            'information about ','info about ','info on ',
            'tell me about ','having name '
        };
        for (String kw : specificKeywords) {
            Integer idx = lp.indexOf(kw);
            if (idx >= 0) {
                String remainder = prompt.substring(idx + kw.length()).trim()
                                         .replaceAll('[?!.]$','').trim();
                if (String.isNotBlank(remainder)) return remainder;
            }
        }

        // Step 3 — Generic single-word keywords (take first CamelCase/underscore token)
        List<String> genericKeywords = new List<String>{
            'apex class ','apex classes ',
            'permission set group ','permission set ',
            'user role ','profile ','flow ','user ',
            'class ','group ','set ','role '
        };
        for (String kw : genericKeywords) {
            Integer idx = lp.indexOf(kw);
            if (idx >= 0) {
                String remainder = prompt.substring(idx + kw.length()).trim()
                                         .replaceAll('[?!.]$','').trim();
                if (String.isNotBlank(remainder)) {
                    // No spaces → clean single name
                    if (!remainder.contains(' ')) return remainder;
                    // First word looks like a name (CamelCase or has underscore)
                    String firstWord = remainder.split('\\s+')[0];
                    if (firstWord.length() > 2 &&
                        (Pattern.matches('[A-Z]', firstWord.substring(0, 1)) || firstWord.contains('_'))) {
                        return firstWord;
                    }
                    return remainder;
                }
            }
        }
        return null;
    }

    private static String extractObjectNameFromQuery(String query) {
        if (String.isBlank(query)) return null;
        try {
            Pattern p = Pattern.compile('(?i)\\bFROM\\s+([A-Za-z][A-Za-z0-9_]*)');
            Matcher m = p.matcher(query);
            if (m.find()) {
                String objName = m.group(1).trim();
                Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
                if (gd.containsKey(objName)) return objName;
                String cap = objName.substring(0,1).toUpperCase() + objName.substring(1);
                if (gd.containsKey(cap)) return cap;
            }
        } catch (Exception e) { System.debug('extractObjectNameFromQuery: ' + e.getMessage()); }
        return null;
    }

    private static Boolean isValidSelectQuery(String q) {
        if (String.isBlank(q) || q.equalsIgnoreCase('NO_QUERY')) return false;
        String lower = q.trim().toLowerCase();
        if (!lower.startsWith('select ')) return false;
        for (String bad : new List<String>{';',' delete ',' insert ',' update ',' upsert ',' merge '})
            if (lower.contains(bad)) return false;
        return true;
    }

    private static String formatFieldValue(Object value) {
        if (value == null) return '';
        if (value instanceof DateTime) return ((DateTime) value).format('yyyy-MM-dd HH:mm');
        if (value instanceof Date)     return ((Date)     value).format();
        if (value instanceof Boolean)  return ((Boolean)  value) ? 'Yes' : 'No';
        String s = String.valueOf(value);
        return s.length() > 50 ? s.substring(0,47) + '...' : s;
    }

    private static String stripCodeFences(String text) {
        if (text == null) return '';
        String r = text.trim();
        if (r.startsWith('```')) {
            Integer last = r.lastIndexOf('```');
            if (last > 0) r = r.substring(r.indexOf('\n') + 1, last).trim();
        }
        return r;
    }

    // ══════════════════════════════════════════════════════════════════════════
    // SYSTEM PROMPTS (ARENAHUB AWARE)
    // ══════════════════════════════════════════════════════════════════════════
    
    private static String getSystemPrompt() {
        return 'You are an expert Salesforce AI Agent. Be concise and production-ready.\n'
             + 'Format ALL code in fenced blocks: ```apex ```soql ```javascript ```html\n'
             + 'Use Markdown tables for structured data. **bold** for key terms. `backticks` for API names.\n'
             + 'Use bullet points and numbered steps where appropriate.';
    }

    private static String getSoqlSystemPrompt() {
        return 'You are a Salesforce SOQL generator for STANDARD Apex Database.query(). '
             + 'RULES: Only generate queries for standard queryable SObjects. '
             + 'NEVER generate queries for Tooling API objects such as: '
             + 'ValidationRule, WorkflowRule, CustomField, CustomObject, ApexTriggerMetadata. '
             + 'If user asks for Tooling API objects, reply with exactly: NO_QUERY. '
             + 'If asking for real Salesforce data, reply ONLY with a valid SOQL SELECT query — '
             + 'no explanation, no fences, no preamble. Otherwise reply: NO_QUERY.\n'
             + getArenaHubSchemaPrompt();
    }

    private static String getArenaHubSchemaPrompt() {
    return '\n=== ARENAHUB FULL PROJECT CONTEXT ===\n'
         // ── Бизнес-контекст ────────────────────────────
         + 'You are an intelligent assistant for the ArenaHub sports ticketing platform built on Salesforce.\n'
         + 'The system manages stadiums, teams, leagues, sport events, ticket inventory, season passes, and fan loyalty.\n'
         + 'It supports dynamic pricing, seat reservations, checkout, check-in, and loyalty accrual.\n\n'
         
         // ── Объекты и поля ─────────────────────────────
         + '--- Custom Objects (ArenaHub) ---\n'
         + 'Sport__c (sport category): Name, League__c, Icon__c, Is_Active__c\n'
         + 'League__c (sports league): Name, Country__c, Season__c, Is_Active__c, Logo_URL__c, Sport__c (lookup to Sport__c)\n'
         + 'Stadium__c (venue): Name, City__c, Address__c, Country__c, Total_Capacity__c, Year_Built__c, Has_Roof__c, Parking_Capacity__c, Transit_Info__c, Emergency_Contact__c\n'
         + 'Stadium_Section__c (seating section): Name, Category__c (picklist: VIP,Premium,Standard,Economy), Row_Count__c, Seats_Per_Row__c, Total_Seats__c (formula: Row_Count__c * Seats_Per_Row__c), Base_Price__c, Is_Active__c, Sort_Order__c, Color_Code__c, Stadium__c (master-detail)\n'
         + 'Team__c (sports team): Name, City__c, Logo_URL__c, Primary_Color__c, Founded_Year__c, Is_Active__c, League__c (lookup), Stadium__c (home stadium lookup)\n'
         + 'Sport_Event__c (sporting event): Name (auto-generated), Season__c, Date_Time__c, Gate_Open_Time__c, Event_Type__c (picklist: Regular Season, Playoff, Quarter-Final, Semi-Final, Final, Derby, Friendly, Cup Match, Exhibition), Status__c (picklist: Scheduled, On Sale, Sold Out, Live, Completed, Cancelled, Postponed), Price_Multiplier__c, Total_Tickets__c (roll-up summary from Ticket__c), Tickets_Sold__c (roll-up summary), Occupancy_Percent__c (formula: IF(Total_Tickets__c=0,0,(Tickets_Sold__c/Total_Tickets__c)*100)), Stadium__c (lookup), Home_Team__c (lookup to Team__c), Away_Team__c (lookup to Team__c), League__c (lookup)\n'
         + 'Purchase_Order__c (ticket purchase order): Order_Number__c (auto), Order_Date__c, Sport_Event__c (lookup), Fan__c (master-detail), Subtotal__c, Discount_Amount__c, Loyalty_Points_Used__c, Points_Value_Applied__c (formula: Loyalty_Points_Used__c/100), Total_Amount__c (formula: MAX(0,Subtotal__c-Discount_Amount__c-Points_Value_Applied__c)), Status__c (picklist: Pending, Confirmed, Cancelled, Refunded), Payment_Method__c (picklist: Card, Cash, Bank Transfer, Other), Promo_Code_Applied__c, Confirmation_Email_Sent__c, Ticket_Count__c (updated by Apex)\n'
         + 'Ticket__c (individual seat ticket): Seat_Key__c (unique text), Seat_Label__c (formula: Section_Name + \'-R\' + Row_Number__c + \'-S\' + Seat_Number__c), Row_Number__c, Seat_Number__c, Base_Price__c, Dynamic_Price__c, Status__c (picklist: Available, Reserved, Sold, Cancelled, Checked In), Reserved_Until__c, QR_Code__c, Is_Season_Pass_Ticket__c, Checked_In_At__c, Sport_Event__c (master-detail), Stadium_Section__c (lookup), Purchase_Order__c (lookup), Season_Pass__c (lookup optional)\n'
         + 'Fan__c (registered fan): First_Name__c, Last_Name__c, Email__c (unique), Phone__c, Date_of_Birth__c, City__c, Registration_Date__c, Loyalty_Tier__c (picklist: Bronze, Silver, Gold, Platinum), Loyalty_Points_Balance__c, Lifetime_Points__c, Total_Spend__c (roll-up from Purchase_Order__c), Events_Attended__c, Preferred_Category__c, Last_Birthday_Bonus_Date__c, Loyalty_Season__c, Favorite_Team__c (lookup to Team__c)\n'
         + 'Season_Pass__c (season subscription): Season__c, Start_Date__c, End_Date__c, Preferred_Row__c, Preferred_Seats__c, Season_Pass_Price__c, Payment_Plan__c (picklist: Full, Monthly), Status__c (picklist: Active, Suspended, Expired, Cancelled), Auto_Renew__c, Renewal_Reminder_Sent__c, Fan__c (lookup), Team__c (lookup), Stadium_Section__c (lookup)\n'
         + 'Loyalty_Transaction__c (points earned/redeemed): Type__c (picklist: Earned, Redeemed, Expired, Adjustment), Points__c, Reason__c (picklist: Purchase, Attendance, Birthday Bonus, Redemption, Admin Adjustment), Transaction_Date__c, Balance_After__c (stored number), Fan__c (master-detail), Purchase_Order__c (lookup)\n'
         
         // ── Бизнес-правила (кратко) ────────────────────
         + '\n--- Key Business Rules ---\n'
         + 'Dynamic Pricing: Dynamic_Price__c = Base_Price__c * Event_Price_Multiplier__c * Demand_Factor * Time_Factor.\n'
         + '  Demand Factor: based on section sold percent (<50%:1.0, 50-69%:1.1, 70-84%:1.2, >=85%:1.35)\n'
         + '  Time Factor: >30 days:0.95, 8-30 days:1.0, 2-7 days:1.1, <48h:1.25\n'
         + '  Loyalty discount at checkout only: Bronze 0%, Silver 5%, Gold 10%, Platinum 15% off Dynamic Price.\n'
         + 'Loyalty Tier thresholds (based on Lifetime_Points__c): Bronze 0+, Silver 500+, Gold 2000+, Platinum 5000+\n'
         + '  Tier upgrade occurs when Lifetime_Points__c crosses threshold; no downgrade during active Loyalty_Season__c.\n'
         + 'Event Status lifecycle: Scheduled -> On Sale -> Sold Out/Live -> Completed/Cancelled/Postponed.\n'
         + 'Tickets can be reserved (15 min), then confirmed or released.\n'
         + 'Season Pass reserves seats on all future home events of the team in the given season.\n'
         + 'Order.Confirmation_Email_Sent__c is set by flow after confirmation.\n\n'
         
         // ── Дополнительные подсказки для SOQL ──────────
         + '--- SOQL Generation Tips ---\n'
         + '- Always use exact API names of objects and fields as shown above.\n'
         + '- For lookups: use e.g. Fan__r.Name, Home_Team__r.Name, Away_Team__r.Name, Stadium__r.Name, etc.\n'
         + '- For master-detail: the parent object name is the relation, e.g. Fan__r, Sport_Event__r.\n'
         + '- Use standard Salesforce functions like TODAY, LAST_N_DAYS, etc.\n'
         + '- When asked about "orders" or "purchases", refer to Purchase_Order__c. When "fans" or "customers", use Fan__c.\n'
         + '- For seat availability, query Ticket__c where Status = \'Available\' for a given event.\n'
         + '- When user asks about revenue, sum Total_Amount__c from Purchase_Order__c with Status = \'Confirmed\'.\n';
    }
}