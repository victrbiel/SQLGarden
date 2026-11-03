"""Tests the real C bridge against a fake ODBC ABI, not a SQL Server substitute."""
import ctypes
import json
import threading
import time
import unittest
from pathlib import Path

bridge = ctypes.CDLL(str(Path('.test-build/bridge.so').resolve()))
bridge.sg_session_create.argtypes = [ctypes.POINTER(ctypes.c_void_p)]
bridge.sg_session_create.restype = ctypes.c_void_p
for name in ('sg_connect', 'sg_execute'):
    fn = getattr(bridge, name)
    fn.restype = ctypes.c_void_p
bridge.sg_connect.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
bridge.sg_execute.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_uint, ctypes.c_uint]
bridge.sg_current_database.argtypes = [ctypes.c_void_p]
bridge.sg_current_database.restype = ctypes.c_void_p
for name in ('sg_string_free', 'sg_cancel', 'sg_session_free'):
    getattr(bridge, name).argtypes = [ctypes.c_void_p]

def consume(pointer):
    assert pointer
    try:
        return ctypes.string_at(pointer).decode('utf-8')
    finally:
        bridge.sg_string_free(pointer)

class BridgeTests(unittest.TestCase):
    def setUp(self):
        error = ctypes.c_void_p()
        self.session = bridge.sg_session_create(ctypes.byref(error))
        self.assertTrue(self.session, consume(error.value) if error.value else 'load failed')
        self.assertTrue(json.loads(consume(bridge.sg_connect(self.session, b'OK')))['success'])

    def tearDown(self):
        bridge.sg_session_free(self.session)

    def execute(self, sql, limit=1000):
        return json.loads(consume(bridge.sg_execute(self.session, sql.encode(), 60, limit)))

    def test_unicode_escaping_null_empty_and_literal_null(self):
        result = self.execute('VALUES')
        self.assertTrue(result['success'])
        self.assertEqual(result['sets'][0]['columns'][0], 'coluna "ação"')
        row = result['sets'][0]['rows'][0]
        self.assertEqual(row, ['ação 🎓 "aspas"\nbarra\\tab\t', None, '', 'NULL'])

    def test_zero_row_dml_keeps_following_results(self):
        result = self.execute('ZERO_FIRST')
        self.assertTrue(result['success'])
        self.assertEqual(len(result['sets']), 1)
        self.assertIn('ação', result['sets'][0]['rows'][0][0])

    def test_multiple_results_dml_and_print(self):
        result = self.execute('MULTI')
        self.assertEqual(len(result['sets']), 3)
        self.assertEqual(result['sets'][1]['affectedRows'], 7)
        self.assertIn('Mensagem de teste', result['messages'])

    def test_embedded_and_trailing_nul_are_preserved(self):
        self.assertEqual(self.execute('NUL')['sets'][0]['rows'][0][0], 'A\0B\0')
        expected = bytearray(b'x' * 10000)
        for index in (0, 4094, 4095, 9999): expected[index] = 0
        self.assertEqual(self.execute('NUL_LONG')['sets'][0]['rows'][0][0], expected.decode())

    def test_binary_warning_does_not_invent_bytes(self):
        result = self.execute('BINARY_WARN')
        self.assertEqual(result['sets'][0]['rows'][0][0], '0x0001FF10')

    def test_streams_long_values(self):
        self.assertEqual(self.execute('LONG')['sets'][0]['rows'][0][0], 'x' * 10000)

    def test_caps_large_cells(self):
        result = self.execute('CAP')['sets'][0]
        self.assertTrue(result['truncated'])
        self.assertIn('[valor limitado]', result['rows'][0][0])

    def test_binary_is_hex(self):
        self.assertEqual(self.execute('BINARY')['sets'][0]['rows'][0][0], '0x0001FF10')

    def test_row_cap_is_visible(self):
        result = self.execute('MANY', limit=3)['sets'][0]
        self.assertEqual(len(result['rows']), 3)
        self.assertTrue(result['truncated'])

    def test_error_preserves_diagnostics(self):
        result = self.execute('ERROR')
        self.assertFalse(result['success'])
        self.assertEqual(result['sets'], [])
        self.assertIn('42000', result['messages'])

    def test_fetch_error_keeps_partial_rows(self):
        result = self.execute('FETCH_ERROR')
        self.assertFalse(result['success'])
        self.assertEqual(len(result['sets'][0]['rows']), 1)

    def test_cell_error_is_valid_json(self):
        result = self.execute('DATA_ERROR')
        self.assertFalse(result['success'])
        self.assertEqual(result['sets'][0]['rows'], [[None]])

    def test_bad_connection_and_reconnect(self):
        bad = json.loads(consume(bridge.sg_connect(self.session, b'BAD')))
        self.assertFalse(bad['success'])
        self.assertFalse(self.execute('VALUES')['success'])
        self.assertTrue(json.loads(consume(bridge.sg_connect(self.session, b'OK')))['success'])

    def test_database_attribute(self):
        self.assertEqual(consume(bridge.sg_current_database(self.session)), 'master')

    def test_cancel_from_other_thread(self):
        result = []
        thread = threading.Thread(target=lambda: result.append(self.execute('CANCEL')))
        thread.start()
        time.sleep(0.05)
        bridge.sg_cancel(self.session)
        thread.join(timeout=2)
        self.assertFalse(thread.is_alive())
        self.assertFalse(result[0]['success'])

if __name__ == '__main__':
    unittest.main(verbosity=2)
