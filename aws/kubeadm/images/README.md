# **Kubernetes Node AMI with Packer**

## **Overview**

This project utilizes HashiCorp's Packer to create a custom Amazon Machine Image (AMI) specifically configured as a Kubernetes node. The AMI is based on Ubuntu 22.04 and includes essential tools and configurations suitable for a Kubernetes environment. The image is designed to run on AWS EC2 instances.

## **Prerequisites**

- Packer >= 1.7.0
- AWS Account with configured access credentials.
- AWS CLI (optional for local setup).

## **Usage**

1. **Clone the Repository**: Clone this repository to your local machine or download the source code.
    
    ```bash
    git clone 
    cd lab/aws/images
    ```
    
2. **Configure AWS Credentials**: Ensure your AWS credentials are configured. This can be done via the AWS CLI or by setting environment variables.
    
    ```bash
    aws configure
    ```
    
3. **Build the AMI**: Run Packer to build the AMI. This will execute the defined steps in the Packer template to create the AMI in your AWS account.
    
    ```bash
    packer build .
    ```
    
4. **Launch EC2 Instances**: Once the AMI is created, you can use it to launch EC2 instances that are pre-configured for Kubernetes.

## **Customization**

- You can modify the scripts under the **`scripts/`** directory to alter the configuration or add additional setup steps.
- Update the Packer template (**`aws-ubuntu.pkr.hcl`**) to change AMI settings, such as the base image or instance type.