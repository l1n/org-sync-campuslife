#!/bin/bash
>&2 echo "Retrieving Organization Names"
curl -s 'https://campuslife.umbc.edu/student-organizations/list-of-student-organizations/' | grep org-name | sed 's/.*href="//; s/http:/https:/; s/".*org-name">/\t/; s/<.*//; s/">/\t/; s/ \t/\t/; s/restling Team/Wrestling Team/; s/LGBT /LGBTQ/;' > organization-names.tsv
>&2 echo "Retrieving Officer Names (for most orgs)"
curl -s 'https://docs.google.com/spreadsheets/d/1bOEoh3B1UR2YvvVp0n29EE1ZQwQp37rHas0JHD8DE98/export?format=tsv&id=1bOEoh3B1UR2YvvVp0n29EE1ZQwQp37rHas0JHD8DE98&gid=1485508862' | tail -n +3 | grep -v 'Student Government Association' | sed "s/\&/\&amp;/g; s/'/\&#8217;/g; s/ \t/\t/g" > organization-officers.tsv
>&2 echo "Retrieving Officer Names (SGA)"
curl -s http://apps.sga.umbc.edu/api/contact | jq -r '.[][] | ["Student Government Association", .position+", "+.unit, .name[0]+" "+.name[1], .email] | join("\t")' - | grep @ >> organization-officers.tsv
>&2 echo "Retrieving Organization Details"
cat organization-names.tsv | xargs -P 20 -d "\n" -I {} perl single-org.pl {} > organizations-attributes.json

>&2 echo "Generating Organization SQL"
echo "CREATE TABLE IF NOT EXISTS organizations_canonical (id INTEGER PRIMARY KEY ASC, name TEXT UNIQUE, category TEXT, description TEXT, organization_group TEXT, website TEXT, facebook TEXT, twitter TEXT, tumblr TEXT, instagram TEXT, email TEXT, mailbox TEXT, cabinet TEXT); DELETE FROM organizations_canonical;" > organizations-canonical.sql
cat organization-names.tsv | perl -ne 'chomp; @p = split /\t/; print "INSERT INTO organizations_canonical (description, name) VALUES ('\''$p[0]'\'', '\''$p[1]'\'');\n"' >> organizations-canonical.sql
jq -r .update_sql organizations-attributes.json >> organizations-canonical.sql

>&2 echo "Executing Organization SQL"
sqlite3 osl.sqlite < organizations-canonical.sql

>&2 echo "Generating Organization ID Lookups"
sqlite3 -separator "	" osl.sqlite "SELECT name, id FROM organizations_canonical" > organizations-lookup.tsv

>&2 echo "Transforming Organization Name to ID"
cat organizations-lookup.tsv | perl -ne 'chomp; @p = split /\t/; $p[0] =~ s/\W/./g; print "sed -i '\''s/^$p[0]/$p[1]/i'\'' organization-officers.tsv\n";' | tee transform-organization-officers.sh | sh

>&2 echo "Backfilling Organizations"
cut -f 1 organization-officers.tsv | uniq | grep -ve '^[0-9]*$' | perl -ne 'chomp; print "INSERT INTO organizations_canonical (name) VALUES ('\''$_'\'');\n"' > organizations-backfill.sql

>&2 echo "Executing Backfill Organization SQL"
sqlite3 osl.sqlite < organizations-backfill.sql

>&2 echo "Regenerating Organization ID Lookups"
sqlite3 -separator "	" osl.sqlite "SELECT name, id FROM organizations_canonical" > organizations-lookup.tsv

>&2 echo "Transforming Organization Name to ID"
cat organizations-lookup.tsv | perl -ne 'chomp; @p = split /\t/; $p[0] =~ s/\W/./g; print "sed -i '\''s/^$p[0]/$p[1]/i'\'' organization-officers.tsv\n";' | tee transform-organization-officers.sh | sh

>&2 echo "Generating Officer Names SQL"
echo "CREATE TABLE IF NOT EXISTS officers (organization_id INTEGER, name TEXT, position TEXT, email TEXT); DELETE FROM officers;" > officers.sql
cat organization-officers.tsv | perl -ne 'chomp; @p = split /\t/; print "INSERT INTO officers (organization_id, position, name, email) VALUES ($p[0], \"$p[1]\", \"$p[2]\", \"$p[3]\");\n";' >> officers.sql

>&2 echo "Executing Officer Names SQL"
sqlite3 osl.sqlite < officers.sql
