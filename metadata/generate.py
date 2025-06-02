# import json
# import os

# base_url = "https://peach-blank-ostrich-116.mypinata.cloud/ipfs/bafybeig54z54iceh3x2kne2r7tagrar3snw3cx5q3bhjxivjoq7kju2nra/"
# total_tokens = 44280
# tokens_per_group = 11070

# # Create a directory to store JSON files
# output_dir = "metadata"
# os.makedirs(output_dir, exist_ok=True)

# for token_id in range(1, total_tokens + 1):
#     # Calculate group and batch
#     group = ((token_id - 1) // tokens_per_group) + 1
#     batch_number = group - 1
    
#     # Determine image extension
#     extension = ".jpeg" if group <= 3 else ".jpg"
#     image_url = f"{base_url}{group}{extension}"
    
#     # Build JSON data
#     data = {
#         "name": f"ur369NFT #{token_id}",
#         "description": "A Soulbound NFT with purpose.",
#         "image": image_url,
#         "attributes": [
#             {"trait_type": "Batch", "value": f"Genesis {batch_number}"},
#             {"trait_type": "Token ID", "value": token_id}
#         ]
#     }
    
#     # Write to file
#     filename = os.path.join(output_dir, f"{token_id}.json")
#     with open(filename, 'w') as f:
#         json.dump(data, f, indent=2)

# print(f"Generated {total_tokens} JSON files in '{output_dir}' directory.")



import json
import os

base_url = "https://peach-blank-ostrich-116.mypinata.cloud/ipfs/bafybeig54z54iceh3x2kne2r7tagrar3snw3cx5q3bhjxivjoq7kju2nra/"
total_tokens = 24
tokens_per_group = 6

output_dir = "metadata"
os.makedirs(output_dir, exist_ok=True)

for token_id in range(1, total_tokens + 1):
    group = ((token_id - 1) // tokens_per_group) + 1
    batch_number = group - 1
    extension = ".jpeg" if group <= 3 else ".jpg"
    
    metadata = {
        "name": f"ur369NFT #{token_id}",
        "description": "A Soulbound NFT with purpose.",
        "image": f"{base_url}{group}{extension}",
        "attributes": [
            {"trait_type": "Batch", "value": f"Genesis {batch_number}"},
            {"trait_type": "Token ID", "value": token_id}
        ]
    }
    
    with open(f"{output_dir}/{token_id}.json", "w") as f:
        json.dump(metadata, f, indent=2)

print(f"Successfully generated {total_tokens} JSON files in '{output_dir}' folder")