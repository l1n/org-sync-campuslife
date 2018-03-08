#!/bin/bash
curl -s 'https://campuslife.umbc.edu/student-organizations/list-of-student-organizations/' | grep org-name | sed 's/.*href="//; s/http:/https:/; s/".*org-name">/\t/; s/<.*//; s/">/\t/' > organization-names.tsv
curl -s 'https://docs.google.com/spreadsheets/d/1bOEoh3B1UR2YvvVp0n29EE1ZQwQp37rHas0JHD8DE98/export?format=tsv&id=1bOEoh3B1UR2YvvVp0n29EE1ZQwQp37rHas0JHD8DE98&gid=1485508862' | tail -n +3 | grep -v 'Student Government Association' > organization-officers.tsv
curl -s http://apps.sga.umbc.edu/api/contact | jq -r '.[][] | ["Student Government Association", .position+", "+.unit, .name[0]+" "+.name[1], .email] | join("\t")' - | grep @ >> organization-officers.tsv
cat organization-names.tsv | xargs -P 20 -d "\n" -I {} perl single-org.pl {} > organizations-attributes.json
echo "CREATE TABLE IF NOT EXISTS organizations_canonical (id INTEGER PRIMARY KEY ASC, name TEXT, category TEXT, description TEXT, organization_group TEXT, website TEXT, facebook TEXT, twitter TEXT, tumblr TEXT, instagram TEXT, email TEXT, mailbox TEXT, cabinet TEXT); DELETE FROM organizations_canonical;" > organizations-canonical.sql
cat organization-names.tsv | perl -ne 'chomp; @p = split /\t/; print "INSERT INTO organizations_canonical (description, name) VALUES ('\''$p[0]'\'', '\''$p[1]'\'');\n"' >> organizations-canonical.sql
jq -r .update_sql organizations-attributes.json >> organizations-canonical.sql
sqlite3 osl.sqlite < organizations-canonical.sql
sqlite3 -separator "    " osl.sqlite "SELECT name, id FROM organizations_canonical" > organizations-lookup.tsv
cat organizations-lookup.tsv | perl -ne 'chomp; @p = split /\t/; print "sed -i '\''s/^$p[0]/$p[1]/'\'' organization-officers.tsv\n";' | sh
echo "CREATE TABLE IF NOT EXISTS officers (organization_id INTEGER, name TEXT, position TEXT, email TEXT); DELETE FROM officers;" > officers.sql
cat organization-officers.tsv | perl -ne 'chomp; @p = split /\t/; print "INSERT INTO officers (organization_id, position, name, email) VALUES ($p[0], \"$p[1]\", \"$p[2]\", \"$p[3]\");\n";' >> officers.sql
sqlite3 osl.sqlite < officers.sql
