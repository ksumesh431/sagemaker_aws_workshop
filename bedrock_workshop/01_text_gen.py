import json
import boto3
import botocore
from IPython.display import display, Markdown
import time

# Initialize Bedrock client
session = boto3.session.Session(region_name="us-east-1")
region = session.region_name
bedrock = boto3.client(service_name="bedrock-runtime", region_name=region)

# # Define model IDs that will be used in this module
# MODELS = {
#     "Claude 3.7 Sonnet": "us.anthropic.claude-3-7-sonnet-20250219-v1:0",
#     "Claude 3.5 Sonnet": "us.anthropic.claude-3-5-sonnet-20240620-v1:0",
#     "Claude 3.5 Haiku": "us.anthropic.claude-3-5-haiku-20241022-v1:0",
#     "Amazon Nova Pro": "us.amazon.nova-pro-v1:0",
#     "Amazon Nova Micro": "us.amazon.nova-micro-v1:0",
#     "DeepSeek-R1": "us.deepseek.r1-v1:0",
#     "Meta Llama 3.1 70B Instruct": "us.meta.llama3-1-70b-instruct-v1:0"
# }
MODELS = {
    # "DeepSeek-R1": "us.deepseek.r1-v1:0",
    "Amazon Nova Micro": "us.amazon.nova-micro-v1:0",
    # "Claude 4.5 Sonnet": "us.anthropic.claude-sonnet-4-5-20250929-v1:0",
    "Llama 4 Maverick 17B Instruct": "us.meta.llama4-maverick-17b-instruct-v1:0"
}


# Utility function to display model responses in a more readable format
def display_response(response, model_name=None):
    if model_name:
        display(Markdown(f"### Response from {model_name}"))
    display(Markdown(response))
    print("\n" + "-" * 80 + "\n")


text_to_summarize = """
AWS took all of that feedback from customers, and today we are excited to announce Amazon Bedrock, \
a new service that makes FMs from AI21 Labs, Anthropic, Stability AI, and Amazon accessible via an API. \
Bedrock is the easiest way for customers to build and scale generative AI-based applications using FMs, \
democratizing access for all builders. Bedrock will offer the ability to access a range of powerful FMs \
for text and images—including Amazons Titan FMs, which consist of two new LLMs we're also announcing \
today—through a scalable, reliable, and secure AWS managed service. With Bedrock's serverless experience, \
customers can easily find the right model for what they're trying to get done, get started quickly, privately \
customize FMs with their own data, and easily integrate and deploy them into their applications using the AWS \
tools and capabilities they are familiar with, without having to manage any infrastructure (including integrations \
with Amazon SageMaker ML features like Experiments to test different models and Pipelines to manage their FMs at scale).
"""


# Create a converse request with our summarization task
converse_request = {
    "messages": [
        {
            "role": "user",
            "content": [
                {
                    "text": f"Please provide a concise summary of the following text in 2-3 sentences. Text to summarize: {text_to_summarize}"
                }
            ],
        }
    ],
    "inferenceConfig": {
        # "temperature": 0.4,
        "topP": 0.9,
        "maxTokens": 500,
    },
}


######################################################################################################
################################# Call DeepSeek-R1 with Converse API #################################
######################################################################################################
def basic_converse():
    print(f"Invoking the basic converse function: \n")
    try:
        response = bedrock.converse(
            modelId=list(MODELS.values())[0],
            messages=converse_request["messages"],
            inferenceConfig=converse_request["inferenceConfig"],
        )

        # Extract the model's response
        deepseek_converse_response = response["output"]["message"]["content"][0]["text"]
        # display_response(deepseek_converse_response, "DeepSeek-R1 (Converse API)")
        print(deepseek_converse_response, "DeepSeek-R1 (Converse API)")
    except botocore.exceptions.ClientError as error:
        if error.response["Error"]["Code"] == "AccessDeniedException":
            print(
                f"\x1b[41m{error.response['Error']['Code']}: {error.response['Error']['Message']}\x1b[0m"
            )
            print(
                "Please ensure you have the necessary permissions for Amazon Bedrock."
            )
        else:
            raise error


######################################################################################################
########################### call different models with the same converse request #####################
######################################################################################################
def different_models_converse():
    print(f"\nInvoking different models with the same converse request: \n")
    results = {}
    for model_name, model_id in MODELS.items():  # looping over all models defined above
        try:
            start_time = time.time()
            response = bedrock.converse(
                modelId=model_id,
                messages=converse_request["messages"],
                inferenceConfig=(
                    converse_request["inferenceConfig"]
                    if "inferenceConfig" in converse_request
                    else None
                ),
            )
            end_time = time.time()

            # Extract the model's response using the correct structure
            model_response = response["output"]["message"]["content"][0]["text"]
            response_time = round(end_time - start_time, 2)

            results[model_name] = {"response": model_response, "time": response_time}

            print(f"✅ Successfully called {model_name} (took {response_time} seconds)")

        except Exception as e:
            print(f"❌ Error calling {model_name}: {str(e)}")
            results[model_name] = {"response": f"Error: {str(e)}", "time": None}

    # Display results in a formatted way
    for model_name, result in results.items():
        if "Error" not in result["response"]:
            # display(Markdown(f"### {model_name} (took {result['time']} seconds)"))
            # display(Markdown(result["response"]))
            print(f"{model_name} (took {result['time']} seconds)")
            print(result["response"])
            print("-" * 80)




def main():
    # basic_converse()
    different_models_converse()

if __name__ == "__main__":
    main()
