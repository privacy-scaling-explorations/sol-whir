use ark_crypto_primitives::merkle_tree::MerkleTree;
use nimue::{plugins::pow::blake3::Blake3PoW, DefaultHash, IOPattern};
use rayon::slice::ParallelSlice;
use std::{error::Error, fs::File, io::Write};
use whir_helper::hasher::{sorted_hasher_config, MerkleTreeParamsSorted};
use whir_helper::proof_converter::convert_proof;

use whir::{
    crypto::fields::Field64,
    parameters::{FoldType, MultivariateParameters, SoundnessType, WhirParameters},
    poly_utils::{coeffs::CoefficientList, MultilinearPoint},
    whir::{
        committer::Committer, iopattern::WhirIOPattern, parameters::WhirConfig, prover::Prover,
        verifier::Verifier, Statement,
    },
};

type MerkleConfig = MerkleTreeParamsSorted<F>;
type PowStrategy = Blake3PoW;
type F = Field64;

use whir::crypto::{
    fields::{self},
    merkle_tree::keccak::KeccakDigest,
};

fn make_whir_things(
    num_variables: usize,
    folding_factor: usize,
    num_points: usize,
    soundness_type: SoundnessType,
    pow_bits: usize,
    fold_type: FoldType,
) {
    let num_coeffs = 1 << num_variables;

    let mut rng = ark_std::test_rng();
    let (leaf_hash_params, two_to_one_params) = sorted_hasher_config::<F>(&mut rng);

    let mv_params = MultivariateParameters::<F>::new(num_variables);

    let whir_params = WhirParameters::<MerkleConfig, PowStrategy> {
        security_level: 32,
        pow_bits,
        folding_factor,
        leaf_hash_params,
        two_to_one_params,
        soundness_type,
        _pow_parameters: Default::default(),
        starting_log_inv_rate: 1,
        fold_optimisation: fold_type,
    };

    let params = WhirConfig::<F, MerkleConfig, PowStrategy>::new(mv_params, whir_params);

    let polynomial = CoefficientList::new(vec![F::from(1); num_coeffs]);

    let points: Vec<_> = (0..num_points)
        .map(|_| MultilinearPoint::rand(&mut rng, num_variables))
        .collect();

    let statement = Statement {
        points: points.clone(),
        evaluations: points
            .iter()
            .map(|point| polynomial.evaluate(point))
            .collect(),
    };

    let io = IOPattern::<DefaultHash>::new("🌪️")
        .commit_statement(&params)
        .add_whir_proof(&params)
        .clone();

    let mut merlin = io.to_merlin();

    let committer = Committer::new(params.clone());
    let witness = committer.commit(&mut merlin, polynomial).unwrap();

    let prover = Prover(params.clone());

    let proof = prover
        .prove(&mut merlin, statement.clone(), witness)
        .unwrap();

    let verifier = Verifier::new(params.clone());
    let mut arthur = io.to_arthur(merlin.transcript());
    assert!(verifier.verify(&mut arthur, &statement, &proof).is_ok());

    // TODO serialize the proof, then read the deserialized proof and convert the merkle proof into OpenZeppelin format
    // for r in 0..params.n_rounds() {
    //     let (merkle_proof, answers) = &proof.0[r];
    // }
}

fn main() -> Result<(), Box<dyn Error>> {
    use fields::Field256 as F;

    /*
    let folding_factors = [1, 2, 3, 4];
    let soundness_type = [
        SoundnessType::ConjectureList,
        SoundnessType::ProvableList,
        SoundnessType::UniqueDecoding,
    ];
    let fold_types = [FoldType::Naive, FoldType::ProverHelps];
    let num_points = [0, 1, 2];
    let pow_bits = [0, 5, 10];

    for folding_factor in folding_factors {
        let num_variables = folding_factor..=3 * folding_factor;
        for num_variables in num_variables {
            for fold_type in fold_types {
                for num_points in num_points {
                    for soundness_type in soundness_type {
                        for pow_bits in pow_bits {
                            make_whir_things(
                                num_variables,
                                folding_factor,
                                num_points,
                                soundness_type,
                                pow_bits,
                                fold_type,
                            );
                        }
                    }
                }
            }
        }
    }
     */

    let mut rng = ark_std::test_rng();
    let (leaf_hash_params, two_to_one_params) = sorted_hasher_config::<F>(&mut rng);

    // Test values
    let leaf_preimages = vec![
        F::from(1),
        F::from(2),
        F::from(3),
        F::from(4),
        F::from(5),
        F::from(6),
        F::from(7),
        F::from(8),
    ];

    let leaves_iter = leaf_preimages.par_chunks_exact(1);

    let merkle_tree = MerkleTree::<MerkleTreeParamsSorted<F>>::new(
        &leaf_hash_params,
        &two_to_one_params,
        leaves_iter,
    )
    .unwrap();

    let indices_to_prove = vec![0, 3, 5];
    let proof = merkle_tree
        .generate_multi_proof(indices_to_prove.clone())
        .unwrap();

    let leaves = get_leaf_hashes(&merkle_tree, &indices_to_prove);

    let converted_proof = convert_proof(&proof, leaves, merkle_tree.root());

    let json_string = serde_json::to_string_pretty(&converted_proof)?;

    let mut file = File::create("proof_output.json")?;
    file.write_all(json_string.as_bytes())?;

    println!("Proof successfully written to `proof_output.json`.");

    Ok(())
}

fn get_leaf_hashes(
    merkle_tree: &MerkleTree<
        MerkleTreeParamsSorted<ark_ff::Fp<ark_ff::MontBackend<fields::BN254Config, 4>, 4>>,
    >,
    indices_to_prove: &Vec<usize>,
) -> Vec<KeccakDigest> {
    indices_to_prove
        .iter()
        // Unfortunately, the Arkworks Merkle tree lacks a method to get the leaf hash directly
        // so we get the "sibling of a sibling" hash instead
        .map(|i| merkle_tree.get_leaf_sibling_hash(*i ^ 1))
        .collect()
}
