void traceDemo() {
  print('demo trace');
  try {
    int.parse('not-a-number');
  } catch (error) {}
}
