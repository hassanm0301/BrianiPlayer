import unittest

from lifecycle_checks import _read_http_response


class LifecycleHttpResponseTests(unittest.TestCase):
    def test_reads_and_decodes_chunked_problem_response(self):
        class FakeSocket:
            def __init__(self):
                self.response = (b"HTTP/1.1 503 Service Unavailable\r\n"
                                 b"Content-Type: application/problem+json\r\n"
                                 b"Transfer-Encoding: chunked\r\n\r\n"
                                 b"23\r\n{\"code\":\"unavailable\",\"status\":503}\r\n"
                                 b"0\r\n\r\n")

            def recv(self, size):
                result, self.response = self.response[:size], self.response[size:]
                return result

        head, body = _read_http_response(FakeSocket())
        self.assertIn(b"503 Service Unavailable", head)
        self.assertEqual(body, b'{"code":"unavailable","status":503}')


if __name__ == "__main__":
    unittest.main()
