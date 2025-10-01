"""
RDS Backup Verification Lambda Function
Verifies latest automated backup can be restored successfully
Runs daily via EventBridge
"""

import boto3
import json
import os
import logging
from datetime import datetime, timedelta
from typing import Dict, Any

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler for backup verification

    Process:
    1. Find latest automated snapshot
    2. Create test restore to verify backup integrity
    3. Validate restored instance is accessible
    4. Clean up test instance
    5. Send alert if any step fails
    """

    db_identifier = os.environ['DB_IDENTIFIER']
    environment = os.environ['ENVIRONMENT']

    rds_client = boto3.client('rds')
    sns_client = boto3.client('sns')

    try:
        logger.info(f"Starting backup verification for {db_identifier}")

        # Step 1: Find latest automated snapshot
        snapshot = find_latest_snapshot(rds_client, db_identifier)
        if not snapshot:
            raise Exception("No automated snapshots found")

        logger.info(f"Found snapshot: {snapshot['DBSnapshotIdentifier']}")

        # Step 2: Create test restore instance
        test_instance_id = f"{db_identifier}-backup-verify-{int(datetime.now().timestamp())}"
        restore_instance(rds_client, snapshot['DBSnapshotIdentifier'], test_instance_id)

        # Step 3: Wait for instance to be available and verify
        wait_for_instance_available(rds_client, test_instance_id)
        verify_instance_health(rds_client, test_instance_id)

        # Step 4: Clean up test instance
        cleanup_test_instance(rds_client, test_instance_id)

        # Step 5: Send success notification
        send_notification(
            sns_client,
            f"✅ Backup verification successful for {db_identifier}",
            f"Snapshot {snapshot['DBSnapshotIdentifier']} verified successfully"
        )

        logger.info("Backup verification completed successfully")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Backup verification successful',
                'snapshot': snapshot['DBSnapshotIdentifier'],
                'timestamp': datetime.now().isoformat()
            })
        }

    except Exception as e:
        error_message = f"Backup verification failed: {str(e)}"
        logger.error(error_message)

        # Send failure notification
        send_notification(
            sns_client,
            f"❌ Backup verification failed for {db_identifier}",
            error_message
        )

        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': error_message,
                'timestamp': datetime.now().isoformat()
            })
        }

def find_latest_snapshot(rds_client: boto3.client, db_identifier: str) -> Dict[str, Any]:
    """Find the most recent automated snapshot"""

    response = rds_client.describe_db_snapshots(
        DBInstanceIdentifier=db_identifier,
        SnapshotType='automated',
        MaxRecords=50
    )

    snapshots = response['DBSnapshots']
    if not snapshots:
        return None

    # Sort by creation time, newest first
    snapshots.sort(key=lambda x: x['SnapshotCreateTime'], reverse=True)

    # Return most recent completed snapshot
    for snapshot in snapshots:
        if snapshot['Status'] == 'available':
            return snapshot

    return None

def restore_instance(rds_client: boto3.client, snapshot_id: str, test_instance_id: str) -> None:
    """Create a test restore from snapshot"""

    logger.info(f"Creating test restore instance: {test_instance_id}")

    rds_client.restore_db_instance_from_db_snapshot(
        DBInstanceIdentifier=test_instance_id,
        DBSnapshotIdentifier=snapshot_id,
        DBInstanceClass='db.t3.micro',  # Use smallest instance for testing
        MultiAZ=False,
        PubliclyAccessible=False,
        DeletionProtection=False,
        Tags=[
            {
                'Key': 'Purpose',
                'Value': 'backup-verification'
            },
            {
                'Key': 'AutoDelete',
                'Value': 'true'
            }
        ]
    )

def wait_for_instance_available(rds_client: boto3.client, instance_id: str, timeout_minutes: int = 20) -> None:
    """Wait for restored instance to become available"""

    logger.info(f"Waiting for instance {instance_id} to become available")

    start_time = datetime.now()
    timeout = timedelta(minutes=timeout_minutes)

    while datetime.now() - start_time < timeout:
        response = rds_client.describe_db_instances(DBInstanceIdentifier=instance_id)
        instance = response['DBInstances'][0]

        status = instance['DBInstanceStatus']
        logger.info(f"Instance status: {status}")

        if status == 'available':
            return
        elif status == 'failed':
            raise Exception(f"Instance {instance_id} failed to start")

        # Wait 30 seconds before checking again
        import time
        time.sleep(30)

    raise Exception(f"Instance {instance_id} did not become available within {timeout_minutes} minutes")

def verify_instance_health(rds_client: boto3.client, instance_id: str) -> None:
    """Verify the restored instance is healthy"""

    response = rds_client.describe_db_instances(DBInstanceIdentifier=instance_id)
    instance = response['DBInstances'][0]

    # Check basic health indicators
    if instance['DBInstanceStatus'] != 'available':
        raise Exception(f"Instance status is {instance['DBInstanceStatus']}, expected 'available'")

    if not instance['Endpoint']:
        raise Exception("Instance endpoint is not available")

    logger.info(f"Instance {instance_id} is healthy with endpoint {instance['Endpoint']['Address']}")

def cleanup_test_instance(rds_client: boto3.client, instance_id: str) -> None:
    """Delete the test restore instance"""

    logger.info(f"Cleaning up test instance: {instance_id}")

    rds_client.delete_db_instance(
        DBInstanceIdentifier=instance_id,
        SkipFinalSnapshot=True,
        DeleteAutomatedBackups=True
    )

def send_notification(sns_client: boto3.client, subject: str, message: str) -> None:
    """Send notification via SNS"""

    # SNS topic ARN is constructed from environment
    topic_arn = f"arn:aws:sns:{boto3.Session().region_name}:{boto3.client('sts').get_caller_identity()['Account']}:{os.environ['ENVIRONMENT']}-backup-alerts"

    try:
        sns_client.publish(
            TopicArn=topic_arn,
            Subject=subject,
            Message=message
        )
        logger.info(f"Notification sent: {subject}")
    except Exception as e:
        logger.error(f"Failed to send notification: {e}")
        # Don't fail the whole function if notification fails