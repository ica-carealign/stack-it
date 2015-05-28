<?xml version="1.0" encoding="UTF-8"?>
<ChangeResourceRecordSetsRequest xmlns="https://route53.amazonaws.com/doc/2013-04-01/">
  <ChangeBatch>
    <Comment>[% Object.Comment %]</Comment>
    <Changes>
      <Change>
        <Action>UPSERT</Action>
        <ResourceRecordSet>
          <Name>[% Object.FQDN %]</Name>
          <Type>A</Type>
          <TTL>3600</TTL>
          <ResourceRecords>
            <ResourceRecord>
              <Value>[% Object.IP %]</Value>
            </ResourceRecord>
          </ResourceRecords>
        </ResourceRecordSet>
      </Change>
    </Changes>
  </ChangeBatch>
</ChangeResourceRecordSetsRequest>
