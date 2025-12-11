#!/usr/bin/env python3
"""
Endpoint testing script for Azure ML deployments.

This script tests ML endpoints with sample data to verify deployment health.
It's used by both GitHub Actions and Azure DevOps pipelines.
"""
import argparse
import json
import requests
import sys
import time


def test_endpoint(url, key, retries=3, timeout=30):
    """
    Test the ML endpoint with sample data.
    
    Args:
        url: Endpoint scoring URI
        key: Endpoint authentication key
        retries: Number of retry attempts
        timeout: Request timeout in seconds
    
    Returns:
        bool: True if test passed, False otherwise
    """
    
    # Sample test data for diabetes classification model
    # Adjust these values based on your actual model's expected input
    test_data = {
        "data": [
            [59, 2, 32.1, 101.0, 157, 93.2, 38.0, 4.0, 4.8598]
        ]
    }
    
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {key}"
    }
    
    for attempt in range(1, retries + 1):
        try:
            print(f"Testing endpoint (attempt {attempt}/{retries}): {url}")
            
            response = requests.post(
                url, 
                json=test_data, 
                headers=headers, 
                timeout=timeout
            )
            
            if response.status_code == 200:
                result = response.json()
                print(f"✓ Test passed - Status: {response.status_code}")
                print(f"Response: {json.dumps(result, indent=2)}")
                
                # Additional validation: check response structure
                if isinstance(result, list) or isinstance(result, dict):
                    print("✓ Response structure is valid")
                    return True
                else:
                    print(f"⚠ Warning: Unexpected response structure: {type(result)}")
                    return True  # Still pass, but warn
                    
            elif response.status_code == 503:
                print(f"⚠ Service unavailable (503) - Endpoint may be initializing")
                if attempt < retries:
                    wait_time = attempt * 5
                    print(f"  Waiting {wait_time}s before retry...")
                    time.sleep(wait_time)
                    continue
                else:
                    print("✗ Test failed - Service remained unavailable")
                    return False
            else:
                print(f"✗ Test failed - Status: {response.status_code}")
                print(f"Response: {response.text}")
                return False
                
        except requests.exceptions.Timeout:
            print(f"✗ Request timeout after {timeout}s")
            if attempt < retries:
                print(f"  Retrying...")
                continue
            return False
            
        except requests.exceptions.ConnectionError as e:
            print(f"✗ Connection error: {str(e)}")
            if attempt < retries:
                print(f"  Retrying...")
                time.sleep(2)
                continue
            return False
            
        except Exception as e:
            print(f"✗ Test failed with exception: {str(e)}")
            return False
    
    print("✗ All retry attempts exhausted")
    return False


def main():
    """Main entry point for the test script."""
    parser = argparse.ArgumentParser(
        description='Test Azure ML endpoint deployment',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python test_endpoint.py --url https://ml-endpoint.azure.com/score --key mykey123
  python test_endpoint.py --url $ENDPOINT_URL --key $ENDPOINT_KEY --retries 5
        """
    )
    
    parser.add_argument(
        '--url', 
        required=True, 
        help='Endpoint scoring URI'
    )
    parser.add_argument(
        '--key', 
        required=True, 
        help='Endpoint authentication key'
    )
    parser.add_argument(
        '--retries', 
        type=int, 
        default=3, 
        help='Number of retry attempts (default: 3)'
    )
    parser.add_argument(
        '--timeout', 
        type=int, 
        default=30, 
        help='Request timeout in seconds (default: 30)'
    )
    
    args = parser.parse_args()
    
    print("=" * 60)
    print("Azure ML Endpoint Test")
    print("=" * 60)
    
    success = test_endpoint(
        args.url, 
        args.key, 
        retries=args.retries, 
        timeout=args.timeout
    )
    
    print("=" * 60)
    if success:
        print("✅ Endpoint test PASSED")
        sys.exit(0)
    else:
        print("❌ Endpoint test FAILED")
        sys.exit(1)


if __name__ == "__main__":
    main()
