"""
Allows a user's IP address to access Concourse's Web nodes by adding the IP address to the relevant Security Group.
This is designed to be invoked via a Lambda URL.
The users IP address and User Id are picked up automatically from the event.

An example call to invoke this lambda looks like:

curl --aws-sigv4 "aws:amz:eu-west-2:lambda" \
--user "$AWS_ACCESS_KEY_ID:$AWS_SECRET_ACCESS_KEY" \
--header "x-amz-security-token:$AWS_SESSION_TOKEN" \
https://xxxxxxxxxxx.lambda-url.eu-west-2.on.aws

"""
import ipaddress
import os

import boto3

client = boto3.client('ec2')


def format_message(message):
    """
    Formats return message into the expected format.
    """
    return {
        'statusCode': 200,
        "headers": {"Content-Type": "text/plain"},
        'body': message,
    }


def handler(event, context):
    group_id = os.getenv('SECURITY_GROUP')

    user = event['requestContext']['authorizer']['iam']['userId'].split(':', 1)[1]

    ip_address = ipaddress.ip_address(event['requestContext']['http']['sourceIp'])
    ip_address_cidr = f"{format(ip_address)}/{ip_address.max_prefixlen}"

    print(f"{user} has requested that {format(ip_address)} be whitelisted.")

    # ---

    paginator = client.get_paginator('describe_security_group_rules')

    response_iterator = paginator.paginate(
        Filters=[{'Name': 'group-id', 'Values': [group_id]}]
    )

    for page in response_iterator:
        for rule in page['SecurityGroupRules']:
            if 'Description' in rule and rule['Description'] == user:

                if rule.get('CidrIpv4', rule.get('CidrIpv6')) == ip_address_cidr:
                    print(f"{user} already has {format(ip_address)} whitelisted.")
                    return format_message(
                        f"The IP address {format(ip_address)} is already setup."
                    )
                else:
                    print(f"{user} already has an IP whitelisted. Removing it.")
                    # Then their IP address has changed, so we delete this entry.
                    client.revoke_security_group_ingress(
                        GroupId=group_id,
                        SecurityGroupRuleIds=[rule['SecurityGroupRuleId']],
                    )
            elif rule.get('CidrIpv4', rule.get('CidrIpv6')) == ip_address_cidr:
                print(
                    f"The IP {format(ip_address)} has already been whitelisted by a different user."
                )
                # Message is not technically ture, but prevents leaking the
                # knowledge that someone has already added the same IP address.
                return format_message(
                    f"The IP address {format(ip_address)} has been added for {user}."
                )

    # If we make it here we can add their IP address.

    permission = {
        'FromPort': 443,
        'ToPort': 443,
        'IpProtocol': 'tcp',
    }

    if ip_address.version == 6:
        permission['Ipv6Ranges'] = [{'CidrIpv6': ip_address_cidr, 'Description': user}]
    else:
        permission['IpRanges'] = [{'CidrIp': ip_address_cidr, 'Description': user}]

    client.authorize_security_group_ingress(
        GroupId=group_id,
        IpPermissions=[permission],
    )

    print(f"The IP {format(ip_address)} has been whitelisted for {user}.")
    return format_message(
        f"The IP address {format(ip_address)} has been added for {user}."
    )
