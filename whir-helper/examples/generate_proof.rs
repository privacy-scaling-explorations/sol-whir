use ark_crypto_primitives::merkle_tree::MerkleTree;
use rand::rngs::StdRng;
use rand::{Rng, SeedableRng};
use rayon::slice::ParallelSlice;
use std::collections::HashSet;
use std::{error::Error, fs::File, io::Write};
use whir_helper::hasher::{sorted_hasher_config, MerkleTreeParamsSorted};
use whir_helper::proof_converter::{convert_proof, get_leaf_hashes};

use whir::crypto::fields::{self};

fn main() -> Result<(), Box<dyn Error>> {
    use fields::Field256 as F;

    let mut rng = ark_std::test_rng();
    let (leaf_hash_params, two_to_one_params) = sorted_hasher_config::<F>(&mut rng);

    let tree_height = 10;
    // For simplicity, the leaf preimages are the integers from 1 to 2^tree_height
    let leaf_preimages: Vec<F> = (1..((1 << tree_height) + 1)).map(|x| F::from(x)).collect();

    let leaves_iter = leaf_preimages.par_chunks_exact(1);

    let merkle_tree = MerkleTree::<MerkleTreeParamsSorted<F>>::new(
        &leaf_hash_params,
        &two_to_one_params,
        leaves_iter,
    )
    .unwrap();

    let mut tree_rng = StdRng::from_entropy();
    //Let's select ~10 random unique indices to prove
    let indices_to_prove: Vec<usize> = (0..100)
        .map(|_| tree_rng.gen_range(0..(1 << tree_height)))
        .collect();

    // Make sure that all indices are unique
    let indices_to_prove_set = HashSet::<usize>::from_iter(indices_to_prove.iter().cloned());
    let indices_to_prove: Vec<usize> = indices_to_prove_set.iter().cloned().collect();

    println!("Indices to prove: {:?}", indices_to_prove);

    let mut indexes = indices_to_prove.clone();
    indexes.sort();

    let proof = merkle_tree.generate_multi_proof(indexes.clone()).unwrap();

    let leaves = get_leaf_hashes(&merkle_tree, &indexes);

    let converted_proof = convert_proof(&proof, leaves, merkle_tree.root());

    let json_string = serde_json::to_string_pretty(&converted_proof)?;

    let mut file = File::create("proof_output.json")?;
    file.write_all(json_string.as_bytes())?;

    println!("Proof successfully written to `proof_output.json`.");

    Ok(())
}
