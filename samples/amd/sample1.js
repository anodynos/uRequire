define(['underscore', 'depdir1/dep1'], function(_, dep1) {
  console.log("\n main starting....");
  dep1 = new dep1();
  dep1.myEach([1, 2, 3], function(val) {
        return console.log('each :' + val);
  });
  return "main";
});