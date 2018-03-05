#!/bin/bash
curl -s 'https://campuslife.umbc.edu/student-organizations/list-of-student-organizations/' | grep org-name | sed 's/.*href="//; s/http:/https:/; s/".*org-name">/\t/; s/<.*//; s/">/\t/' > organization-names.tsv
curl -s 'https://docs.google.com/spreadsheets/d/1bOEoh3B1UR2YvvVp0n29EE1ZQwQp37rHas0JHD8DE98/export?format=tsv&id=1bOEoh3B1UR2YvvVp0n29EE1ZQwQp37rHas0JHD8DE98&gid=1485508862' | tail -n +3 | grep -v 'Student Government Association' > organization-officers.tsv
curl -s http://apps.sga.umbc.edu/api/contact | jq -r '.[][] | ["Student Government Association", .position+", "+.unit, .name[0]+" "+.name[1], .email] | join("\t")' - | grep @ >> organization-officers.tsv

cat organization-names.tsv | xargs -P 20 -d "\n" -I {} perl single-org.pl {} > organizations-attributes.json

cat organization-names.tsv | perl -ne 'chomp; @p = split /\t/; print "INSERT INTO organizations_canonical (description, name) VALUES ('\''$p[0]'\'', '\''$p[1]'\'');\n"' > organizations-canonical.sql
jq -r .update_sql organizations-attributes.json >> organizations-canonical.sql
