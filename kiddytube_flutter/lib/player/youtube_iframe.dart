/// Kid-safe YouTube iframe HTML (nocookie host, minimal chrome).
/// Mirrors Kotlin [PlayerActivity.playYoutube] bridge contract.
String youtubeIframeHtml({
  required String videoId,
  double startSec = 0,
}) {
  final safeId = videoId.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
  final start = startSec < 0 ? 0 : startSec;
  return '''
<!DOCTYPE html>
<html><head>
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
<style>
  html,body{margin:0;padding:0;width:100%;height:100%;background:#000;overflow:hidden;
    display:flex;align-items:center;justify-content:center}
  #stage{position:relative;background:#000;overflow:hidden;width:100%;height:100%}
  #stage iframe{pointer-events:none;border:0;display:block;width:100%;height:100%}
</style></head><body>
<div id="stage"><div id="p"></div></div>
<script src="https://www.youtube.com/iframe_api"></script>
<script>
  var player;
  var startSec=$start;
  function size(){
    var w=window.innerWidth||document.documentElement.clientWidth||320;
    var h=window.innerHeight||document.documentElement.clientHeight||180;
    return {w:w,h:h};
  }
  function onYouTubeIframeAPIReady(){
    var sz=size();
    player=new YT.Player('p',{
      width:sz.w,height:sz.h,
      videoId:'$safeId',
      host:'https://www.youtube-nocookie.com',
      playerVars:{
        autoplay:1,controls:0,disablekb:1,fs:0,iv_load_policy:3,
        modestbranding:1,rel:0,playsinline:1,cc_load_policy:0,
        showinfo:0,origin:location.origin,
        start:Math.max(0,Math.floor(startSec||0))
      },
      events:{
        onReady:function(e){ try{e.target.playVideo();}catch(err){} },
        onStateChange:function(e){
          if(e.data===0 && window.KiddyNative) KiddyNative.postMessage('ended');
        },
        onError:function(e){
          if(window.KiddyNative) KiddyNative.postMessage('error:'+e.data);
        }
      }
    });
  }
  window.addEventListener('resize',function(){
    if(!player||!player.setSize) return;
    var sz=size();
    player.setSize(sz.w,sz.h);
  });
</script></body></html>
''';
}
