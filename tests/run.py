import unittest
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from tests.test_indexer_search import IndexerSearchTest
from tests.test_metainfo import MetaInfoTest

if __name__ == '__main__':
    suite = unittest.TestSuite()
    # 测试名称识别
    suite.addTest(MetaInfoTest('test_metainfo'))
    suite.addTest(IndexerSearchTest('test_remote_indexer_default_workers_are_capped'))
    suite.addTest(IndexerSearchTest('test_remote_indexer_workers_use_config_without_exceeding_indexer_count'))
    suite.addTest(IndexerSearchTest('test_builtin_indexer_keeps_full_parallelism'))
    suite.addTest(IndexerSearchTest('test_torznab_timeout_uses_config_with_default'))

    # 运行测试
    runner = unittest.TextTestRunner()
    runner.run(suite)
