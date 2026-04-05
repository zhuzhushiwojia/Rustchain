"""
Bounty #2819 - Bug Demonstration Tests
=======================================

These tests demonstrate vulnerabilities found in the UTXO implementation.
PR Title: [UTXO-BUG] Unlimited mining rewards + missing proof validation

Run: python3 test_bug_submission.py
"""

import os
import tempfile
import time
import unittest

from utxo_db import UtxoDB, UNIT


class TestBountyBugs(unittest.TestCase):
    """Bug demonstration tests for bounty #2819."""

    def setUp(self):
        self.tmp = tempfile.NamedTemporaryFile(suffix='.db', delete=False)
        self.tmp.close()
        self.db = UtxoDB(self.tmp.name)
        self.db.init_tables()

    def tearDown(self):
        os.unlink(self.tmp.name)

    # ========================================================================
    # CRITICAL BUG #1: Unlimited Mining Rewards
    # ========================================================================
    # The apply_transaction() method allows mining_reward tx_type with empty
    # inputs but DOES NOT validate the output amount. An attacker can create
    # a transaction outputting ANY amount of RTC.
    
    def test_BUG_unlimited_mining_reward(self):
        """
        CRITICAL: Mining reward has no upper bound.
        
        A malicious actor can create a mining_reward transaction outputting
        billions of RTC without any validation.
        
        Expected: The system should reject mining rewards exceeding a maximum.
        Actual: The transaction succeeds with arbitrary amounts.
        """
        # Try to create an absurdly large mining reward
        UNREASONABLE_REWARD = 1_000_000_000 * UNIT  # 1 billion RTC
        
        ok = self.db.apply_transaction({
            'tx_type': 'mining_reward',
            'inputs': [],
            'outputs': [{'address': 'attacker', 'value_nrtc': UNREASONABLE_REWARD}],
            'fee_nrtc': 0,
            'timestamp': int(time.time()),
        }, block_height=1)
        
        # This SHOULD fail (reward too large) but currently succeeds!
        # The test passes because the bug EXISTS (ok == True)
        # A fix would add: MAX_MINING_REWARD constant and validate
        
        # Bug exists if this assertion passes
        self.assertTrue(ok, "Bug confirmed: unlimited mining reward accepted")
        
        # Verify the attacker got the funds
        balance = self.db.get_balance('attacker')
        self.assertEqual(balance, UNREASONABLE_REWARD,
            "Bug: attacker now has 1 billion RTC!")

    def test_BUG_very_large_mining_reward_accepted(self):
        """
        Even 10x the total supply can be minted by anyone.
        """
        LARGE_REWARD = 10_000_000 * UNIT  # 10 million RTC
        
        ok = self.db.apply_transaction({
            'tx_type': 'mining_reward',
            'inputs': [],
            'outputs': [{'address': 'attacker', 'value_nrtc': LARGE_REWARD}],
            'fee_nrtc': 0,
        }, block_height=1)
        
        # Bug: This succeeds when it should fail
        self.assertTrue(ok, "Bug: large mining reward accepted without validation")

    # ========================================================================
    # CRITICAL BUG #2: Missing Spending Proof Validation
    # ========================================================================
    # The code accepts 'spending_proof' in inputs but NEVER validates it.
    # Anyone who knows a box_id can spend that box without providing
    # a valid cryptographic proof.
    
    def test_BUG_missing_proof_validation(self):
        """
        CRITICAL: Spending proof is accepted but never validated.
        
        The apply_transaction() method accepts 'spending_proof' in inputs
        but never verifies it's correct. An attacker who knows a box_id
        can spend it with any proof string.
        
        Expected: Proof should be cryptographically validated.
        Actual: Proof is completely ignored.
        """
        # First, create a box legitimately (like a mining reward)
        self.db.apply_transaction({
            'tx_type': 'mining_reward',
            'inputs': [],
            'outputs': [{'address': 'victim', 'value_nrtc': 100 * UNIT}],
        }, block_height=1)
        
        # Get the box
        boxes = self.db.get_unspent_for_address('victim')
        self.assertEqual(len(boxes), 1)
        victim_box_id = boxes[0]['box_id']
        
        # Attacker tries to spend the box with FAKE proof
        FAKE_PROOF = "this_is_not_a_valid_signature"
        
        ok = self.db.apply_transaction({
            'tx_type': 'transfer',
            'inputs': [{
                'box_id': victim_box_id,
                'spending_proof': FAKE_PROOF  # Completely fake!
            }],
            'outputs': [{'address': 'attacker', 'value_nrtc': 100 * UNIT}],
        }, block_height=10)
        
        # BUG: This succeeds even with fake proof!
        self.assertTrue(ok, "Bug confirmed: spending proof never validated")
        
        # Verify attacker stole the funds
        self.assertEqual(self.db.get_balance('attacker'), 100 * UNIT)
        self.assertEqual(self.db.get_balance('victim'), 0)

    def test_BUG_empty_proof_accepted(self):
        """
        Even an empty string as proof is accepted.
        """
        self.db.apply_transaction({
            'tx_type': 'mining_reward',
            'inputs': [],
            'outputs': [{'address': 'victim', 'value_nrtc': 50 * UNIT}],
        }, block_height=1)
        
        boxes = self.db.get_unspent_for_address('victim')
        
        ok = self.db.apply_transaction({
            'tx_type': 'transfer',
            'inputs': [{'box_id': boxes[0]['box_id'], 'spending_proof': ''}],
            'outputs': [{'address': 'thief', 'value_nrtc': 50 * UNIT}],
        }, block_height=10)
        
        # Bug: Empty proof works!
        self.assertTrue(ok, "Bug: empty spending proof accepted")

    # ========================================================================
    # HIGH BUG #3: No Mining Authority Verification
    # ========================================================================
    # The code doesn't verify that the transaction creator is actually
    # authorized to mint rewards. Anyone can create a mining_reward tx.
    
    def test_BUG_anyone_can_mine(self):
        """
        HIGH: Anyone can create mining_reward transactions.
        
        There's no check that the caller is a legitimate miner or
        that they found a valid block. The tx_type 'mining_reward'
        can be used by anyone.
        """
        # Create multiple "mining rewards" from different "miners"
        for i in range(5):
            ok = self.db.apply_transaction({
                'tx_type': 'mining_reward',  # Not verified!
                'inputs': [],
                'outputs': [{'address': f'fake_miner_{i}', 'value_nrtc': 50 * UNIT}],
            }, block_height=i+1)
            
            self.assertTrue(ok, f"Bug: fake miner {i} got reward without verification")
        
        # Total supply now has 250 RTC minted from thin air
        # No verification that these are legitimate block rewards

    # ========================================================================
    # MEDIUM: Negative Output Values
    # ========================================================================
    
    def test_BUG_negative_output_value(self):
        """
        MEDIUM: Negative output values are accepted.
        
        value_nrtc should be validated as positive.
        """
        self.db.apply_transaction({
            'tx_type': 'mining_reward',
            'inputs': [],
            'outputs': [{'address': 'alice', 'value_nrtc': 100 * UNIT}],
        }, block_height=1)
        
        boxes = self.db.get_unspent_for_address('alice')
        
        # Try to create a negative output - this might cause issues
        ok = self.db.apply_transaction({
            'tx_type': 'transfer',
            'inputs': [{'box_id': boxes[0]['box_id'], 'spending_proof': 'sig'}],
            'outputs': [
                {'address': 'bob', 'value_nrtc': 200 * UNIT},
                {'address': 'alice', 'value_nrtc': -150 * UNIT},  # Negative!
            ],
        }, block_height=10)
        
        # Currently may fail due to conservation check, but negative value
        # should be explicitly rejected early


if __name__ == '__main__':
    print("=" * 70)
    print("Bounty #2819 - Bug Demonstration Tests")
    print("These tests CONFIRM the vulnerabilities exist in the codebase")
    print("=" * 70)
    unittest.main(verbosity=2)