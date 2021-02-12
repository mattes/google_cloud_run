require "test_helper"

class GoogleCloudRunTest < ActiveSupport::TestCase
  test "it has a version number" do
    assert GoogleCloudRun::VERSION
  end

  test "k_service" do
    ENV["K_SERVICE"] = "service-123"
    ENV["K_REVISION"] = "service-123-00012-foo"
    assert_equal GoogleCloudRun.k_service, "service-123"
  end

  test "k_revision" do
    ENV["K_SERVICE"] = "service-123"
    ENV["K_REVISION"] = "service-123-00012-foo"
    assert_equal GoogleCloudRun.k_revision, "00012-foo"
    assert_equal GoogleCloudRun.k_revision, "00012-foo"
  end

  test "project_id" do
    assert_equal GoogleCloudRun.project_id, "dummy-project"
  end

  test "parse_trace_context" do
    trace, span, sample = GoogleCloudRun.parse_trace_context("5nef4899ceup779865dd3f4n2922od0u/395751616145821407;o=1")
    assert_equal trace, "5nef4899ceup779865dd3f4n2922od0u"
    assert_equal span, "395751616145821407"
    assert_equal sample, true

    trace, span, sample = GoogleCloudRun.parse_trace_context("5nef4899ceup779865dd3f4n2922od0u/395751616145821407;o=0")
    assert_equal trace, "5nef4899ceup779865dd3f4n2922od0u"
    assert_equal span, "395751616145821407"
    assert_equal sample, false

    trace, span, sample = GoogleCloudRun.parse_trace_context("5nef4899ceup779865dd3f4n2922od0u/395751616145821407;o=")
    assert_equal trace, "5nef4899ceup779865dd3f4n2922od0u"
    assert_equal span, "395751616145821407"
    assert_nil sample

    trace, span, sample = GoogleCloudRun.parse_trace_context("5nef4899ceup779865dd3f4n2922od0u/395751616145821407")
    assert_equal trace, "5nef4899ceup779865dd3f4n2922od0u"
    assert_equal span, "395751616145821407"
    assert_nil sample

    trace, span, sample = GoogleCloudRun.parse_trace_context("5nef4899ceup779865dd3f4n2922od0u/")
    assert_equal trace, "5nef4899ceup779865dd3f4n2922od0u"
    assert_nil span
    assert_nil sample

    trace, span, sample = GoogleCloudRun.parse_trace_context("5nef4899ceup779865dd3f4n2922od0u")
    assert_equal trace, "5nef4899ceup779865dd3f4n2922od0u"
    assert_nil span
    assert_nil sample

    trace, span, sample = GoogleCloudRun.parse_trace_context("")
    assert_nil trace
    assert_nil span
    assert_nil sample

    trace, span, sample = GoogleCloudRun.parse_trace_context("5nef4899ceup779865dd3f4n2922od0u/395751616145821407;o=1;foo=bar")
    assert_equal trace, "5nef4899ceup779865dd3f4n2922od0u"
    assert_equal span, "395751616145821407"
    assert_equal sample, true
  end
end
