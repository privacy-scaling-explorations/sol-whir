use ark_crypto_primitives::merkle_tree::MultiPath;
use serde::{ser::SerializeStruct, Serialize, Serializer};
use std::collections::{HashMap, HashSet};

use whir::crypto::{
    fields::{self},
    merkle_tree::keccak::KeccakDigest,
};

use crate::hasher::MerkleTreeParamsSorted;

pub struct OpenZeppelinMultiProof {
    leaves: Vec<KeccakDigest>,
    proof: Vec<KeccakDigest>,
    proof_flags: Vec<bool>,
    root: KeccakDigest,
}

impl Serialize for OpenZeppelinMultiProof {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        let mut state = serializer.serialize_struct("OpenZeppelinMultiProof", 3)?;

        state.serialize_field(
            "leaves",
            &self
                .leaves
                .iter()
                // "0x" is necessary for Foundry to recognize it as bytes32
                .map(|digest| "0x".to_owned() + &hex::encode(digest.as_ref()))
                .collect::<Vec<String>>(),
        )?;
        state.serialize_field(
            "proof",
            &self
                .proof
                .iter()
                // "0x" is necessary for Foundry to recognize it as bytes32
                .map(|digest| "0x".to_owned() + &hex::encode(digest.as_ref()))
                .collect::<Vec<String>>(),
        )?;
        state.serialize_field("proofFlags", &self.proof_flags)?;
        state.serialize_field(
            "root",
            // "0x" is necessary for Foundry to recognize it as bytes32
            &("0x".to_owned() + &hex::encode(self.root.as_ref())),
        )?;

        state.end()
    }
}

pub fn convert_proof(
    proof: &MultiPath<
        MerkleTreeParamsSorted<ark_ff::Fp<ark_ff::MontBackend<fields::BN254Config, 4>, 4>>,
    >,
    leaves: Vec<KeccakDigest>,
    root: KeccakDigest,
) -> OpenZeppelinMultiProof {
    let path_len = proof.auth_paths_suffixes[0].len();
    let tree_height = path_len + 1;

    let mut node_by_tree_index = HashMap::<usize, KeccakDigest>::new();
    let mut calculated_node_tree_indices = HashSet::<usize>::new();

    let mut converted_proof = vec![];
    let mut converted_proof_flags: Vec<bool> = vec![];

    let mut prev_path: Vec<_> = proof.auth_paths_suffixes[0].clone();
    for (i, leaf_idx) in proof.leaf_indexes.iter().enumerate() {
        // Determine if sibling is a part of "main queue" or "proof"
        let sibling_idx = leaf_idx ^ 1;
        if proof.leaf_indexes.contains(&sibling_idx) {
            if sibling_idx > *leaf_idx {
                // For a pair, push the flag only once!
                converted_proof_flags.push(true);
            }
        } else {
            converted_proof.push(proof.leaf_siblings_hashes[i]);
            converted_proof_flags.push(false);
        }

        // Decode the full auth path
        let path = prefix_decode_path(
            &prev_path,
            proof.auth_paths_prefix_lenghts[i],
            &proof.auth_paths_suffixes[i],
        );
        prev_path = path.clone();

        // For each path, determine the indices of the auth path nodes above leaf level
        let mut parent_level_idx = leaf_idx >> 1;
        for level in (1..tree_height).rev() {
            // All the parents along the path will be calculated during the proof verification
            calculated_node_tree_indices.insert(to_tree_index(parent_level_idx, level));
            let parent_sibling_level_idx = parent_level_idx ^ 1;
            // We "cache" the auth path nodes to later pick ones that won't be calculated in any of the paths
            node_by_tree_index.insert(
                to_tree_index(parent_sibling_level_idx, level),
                // The path goes from root to leaves, so we need to reverse
                path[level - 1],
            );
            parent_level_idx = parent_level_idx >> 1;
        }
    }

    // Second pass
    for level in (1..path_len + 1).rev() {
        // For each level, find nodes that won't be calculated
        let level_size = 1 << level;
        for i in 0..level_size {
            if calculated_node_tree_indices.contains(&to_tree_index(i, level)) {
                let sibling_idx = i ^ 1;
                let sibling_tree_idx = &to_tree_index(sibling_idx, level);
                if calculated_node_tree_indices.contains(sibling_tree_idx) {
                    // Both siblings are calculated. Adding true flag only once:
                    if sibling_idx > i {
                        converted_proof_flags.push(true);
                    }
                } else if node_by_tree_index.contains_key(sibling_tree_idx) {
                    converted_proof.push(node_by_tree_index[sibling_tree_idx]);
                    converted_proof_flags.push(false);
                }
            }
        }
    }

    OpenZeppelinMultiProof {
        leaves,
        proof: converted_proof,
        proof_flags: converted_proof_flags,
        root,
    }
}

fn to_tree_index(level_index: usize, level: usize) -> usize {
    (1 << level) + level_index - 1
}

// Adapted from ark-crypto-primitives (it's private there)
fn prefix_decode_path<T>(prev_path: &[T], prefix_len: usize, suffix: &Vec<T>) -> Vec<T>
where
    T: Eq + Clone,
{
    if prefix_len == 0 {
        suffix.to_owned()
    } else {
        [prev_path[0..prefix_len].to_vec(), suffix.to_owned()].concat()
    }
}
