import importlib.util, pathlib, unittest
ROOT=pathlib.Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('egress_probe_under_test',ROOT/'tools/security/egress_probe.py')
probe=importlib.util.module_from_spec(spec);spec.loader.exec_module(probe)

class EvidenceTests(unittest.TestCase):
    def test_unexercised_or_zero_packet_path_cannot_pass(self):
        self.assertEqual('not_proven',probe.decide(0,1,0));self.assertEqual('not_proven',probe.decide(1,0,0));self.assertEqual('not_proven',probe.decide(1,1,0,phases_ok=False))
    def test_any_receiver_hit_fails_even_with_reject_packets(self):self.assertEqual('failed',probe.decide(1,8,1))
    def test_observed_positive_and_denied_attempt_prove_one_path(self):self.assertEqual('passed',probe.decide(1,1,0))
    def test_negative_counter_never_installs_its_own_denial(self):
        rule=probe.fixture_rule('172.20.0.3',18100,'owned-counter')
        self.assertIn('counter',rule);self.assertNotIn('reject',rule);self.assertNotIn('drop',rule);self.assertNotIn('accept',rule)
    def test_fixture_exception_has_one_exact_target(self):
        rule=probe.fixture_rule('172.20.0.2',18080,'owned-origin',allow=True)
        self.assertIn('accept',rule)
        with self.assertRaises(ValueError):probe.fixture_rule('8.8.8.8',18080,'external',allow=True)
        with self.assertRaises(ValueError):probe.fixture_rule('172.20.0.2',0,'invalid',allow=True)
    def test_baseline_cannot_be_overwritten(self):
        with self.assertRaisesRegex(ValueError,'preserve baseline'):probe.probe(ROOT/'docs/evidence/M10/egress.json')

if __name__=='__main__':unittest.main()
