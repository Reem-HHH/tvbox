import '../catalog/media_ids.dart';

/// Kid-safe YouTube iframe HTML (nocookie host, minimal chrome).
/// Mirrors Kotlin [PlayerActivity.playYoutube] bridge contract.
String youtubeIframeHtml({
  required String videoId,
  double startSec = 0,
}) {
  if (!MediaIds.isValidVideoId(videoId)) {
    throw ArgumentError.value(videoId, 'videoId', 'Invalid YouTube video id');
  }
  // Allowlisted charset only — safe to embed without further escaping.
  final safeId = videoId.trim();
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
  #cover{position:absolute;inset:0;background:#000;display:none;z-index:5}
</style></head><body>
<div id="stage"><div id="p"></div><div id="cover"></div></div>
<script src="https://www.youtube.com/iframe_api"></script>
<script>
  var player;
  var startSec=$start;
  var endedSent=false;
  function size(){
    var w=window.innerWidth||document.documentElement.clientWidth||320;
    var h=window.innerHeight||document.documentElement.clientHeight||180;
    return {w:w,h:h};
  }
  function hideRelated(){
    var c=document.getElementById('cover');
    if(c) c.style.display='block';
  }
  function sendEnded(){
    if(endedSent) return;
    endedSent=true;
    hideRelated();
    try{ if(player&&player.pauseVideo) player.pauseVideo(); }catch(e){}
    if(window.KiddyNative) KiddyNative.postMessage('ended');
  }
  function progressSnapshot(){
    try{
      if(!player||!player.getCurrentTime) return JSON.stringify({pos:0,dur:0});
      var pos=Math.floor((player.getCurrentTime()||0)*1000);
      var dur=Math.floor((player.getDuration()||0)*1000);
      return JSON.stringify({pos:pos,dur:dur});
    }catch(e){
      return JSON.stringify({pos:0,dur:0});
    }
  }
  function seekBy(deltaSec){
    try{
      if(!player||!player.getCurrentTime||!player.seekTo) return;
      var t=(player.getCurrentTime()||0)+deltaSec;
      if(t<0) t=0;
      var d=player.getDuration?player.getDuration():0;
      if(typeof d==='number'&&d>0&&t>d-1) t=Math.max(0,d-1);
      player.seekTo(t,true);
    }catch(e){}
  }
  function seekToAbs(sec){
    try{
      if(!player||!player.seekTo) return;
      var t=Number(sec)||0;
      if(t<0) t=0;
      var d=player.getDuration?player.getDuration():0;
      if(typeof d==='number'&&d>0&&t>d-1) t=Math.max(0,d-1);
      player.seekTo(t,true);
      if(player.playVideo) player.playVideo();
    }catch(e){}
  }
  function pausePlayback(){
    try{ if(player&&player.pauseVideo) player.pauseVideo(); }catch(e){}
  }
  function togglePlayPause(){
    try{
      if(!player||!player.getPlayerState) return;
      var s=player.getPlayerState();
      if(s===1) player.pauseVideo();
      else player.playVideo();
    }catch(e){}
  }
  function loadVideoById(id,start){
    try{
      if(!player||!player.loadVideoById) return false;
      var t=Number(start)||0;
      if(t<0) t=0;
      player.loadVideoById({
        videoId:String(id||''),
        startSeconds:Math.max(0,Math.floor(t))
      });
      endedSent=false;
      var c=document.getElementById('cover');
      if(c) c.style.display='none';
      return true;
    }catch(e){ return false; }
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
          if(e.data===0) sendEnded();
        },
        onError:function(e){
          if(window.KiddyNative) KiddyNative.postMessage('error:'+e.data);
        }
      }
    });
    setInterval(function(){
      try{
        if(endedSent||!player||!player.getCurrentTime||!player.getDuration) return;
        var d=player.getDuration()||0;
        var t=player.getCurrentTime()||0;
        if(d>3 && t>=d-1.2) sendEnded();
      }catch(e){}
    },250);
  }
  window.addEventListener('resize',function(){
    if(!player||!player.setSize) return;
    var sz=size();
    player.setSize(sz.w,sz.h);
  });
</script></body></html>
''';
}
