"""
Flushes all ingress rules from the defined security group.

Designed to be triggered on a cron job and run against the Web Node's Security Group which containing
end user IP addresses.
"""
import os

import boto3

client = boto3.client('ec2')


def handler(event, context):
    group_id = os.getenv('SECURITY_GROUP')

    paginator = client.get_paginator('describe_security_group_rules')

    response_iterator = paginator.paginate(
        PaginationConfig={
            'MaxResults': 10,
        },
        Filters=[{'Name': 'group-id', 'Values': [group_id]}],
    )

    for page in response_iterator:
        # Maps all rule ids returned on the page into a single list.
        rule_ids = [rule['SecurityGroupRuleId'] for rule in page['SecurityGroupRules']]

        # Batch removes all ids found on the current page.
        client.revoke_security_group_ingress(
            GroupId=group_id,
            SecurityGroupRuleIds=rule_ids,
        )
