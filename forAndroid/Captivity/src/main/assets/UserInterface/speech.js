// Copyright 2020 VMware, Inc.  
// SPDX-License-Identifier: BSD-2-Clause


export default class Speech {
    constructor() {
        this._speechSynthesis = window.speechSynthesis;
        this._voices = undefined;
    }

    get voices() {return this._voices;}

    initialise(readyCallback) {
        this._populateVoiceList(false, readyCallback);
        if (this._speechSynthesis.onvoiceschanged !== undefined) {
            this._speechSynthesis.onvoiceschanged = 
                this._populateVoiceList.bind(this, true, readyCallback);
        }    
    }

    _populateVoiceList(forceReady, readyCallback) {
        if (this._speechSynthesis === undefined) {
            this._voices = [];
            readyCallback(this);
        }
        const language = navigator.language;
        this._voices = this._speechSynthesis.getVoices();
        this._voices.sort((a, b) => //a.name.localeCompare(b.name));
        {
            if (a.default && !b.default) {return -1;}
            if (!a.default && b.default) {return 1;}
            if (a.lang === language && b.lang !== language) {return -1;}
            if (a.lang !== language && b.lang === language) {return 1;}
            if (a.lang < b.lang) {return -1;}
            if (a.lang > b.lang) {return 1;}
            return a.name.localeCompare(b.name);
        });
        if (this._voices.length <= 0) {
            if (forceReady) {
                readyCallback(this);
            }
            return;
        }
        readyCallback(this);
            
    //  {
        //  return a.localeCompare(b);
    //   const aname = a.name.toUpperCase(), bname = b.name.toUpperCase();
    //   if ( aname < bname ) return -1;
    //   else if ( aname == bname ) return 0;
    //   else return +1;
//   });

//   var selectedIndex = voiceSelect.selectedIndex < 0 ? 0 : voiceSelect.selectedIndex;
//   voiceSelect.innerHTML = '';
//   for(i = 0; i < voices.length ; i++) {
//     var option = document.createElement('option');
//     option.textContent = voices[i].name + ' (' + voices[i].lang + ')';
    
//     if(voices[i].default) {
//       option.textContent += ' -- DEFAULT';
//     }

//     option.setAttribute('data-lang', voices[i].lang);
//     option.setAttribute('data-name', voices[i].name);
//     voiceSelect.appendChild(option);
//   }
//   voiceSelect.selectedIndex = selectedIndex;
    }

// if (speechSynthesis.onvoiceschanged !== undefined) {
//   speechSynthesis.onvoiceschanged = populateVoiceList;
// }

// function speak(){
//     if (synth.speaking) {
//         console.error('speechSynthesis.speaking');
//         return;
//     }
//     if (inputTxt.value !== '') {
//     var utterThis = new SpeechSynthesisUtterance(inputTxt.value);
//     utterThis.onend = function (event) {
//         console.log('SpeechSynthesisUtterance.onend');
//     }
//     utterThis.onerror = function (event) {
//         console.error('SpeechSynthesisUtterance.onerror');
//     }
//     var selectedOption = voiceSelect.selectedOptions[0].getAttribute('data-name');
//     for(i = 0; i < voices.length ; i++) {
//       if(voices[i].name === selectedOption) {
//         utterThis.voice = voices[i];
//         break;
//       }
//     }
//     utterThis.pitch = pitch.value;
//     utterThis.rate = rate.value;
//     synth.speak(utterThis);
//   }
// }

// inputForm.onsubmit = function(event) {
//   event.preventDefault();

//   speak();

//   inputTxt.blur();
// }

// pitch.onchange = function() {
//   pitchValue.textContent = pitch.value;
// }

// rate.onchange = function() {
//   rateValue.textContent = rate.value;
// }

// voiceSelect.onchange = function(){
//   speak();
// }

    speak(voiceIndex, text) {
        if (this._speechSynthesis === undefined) {
            return false;
        }
        console.log(`Speak "${text}" by ${voiceIndex}.`);
        const utterance = new SpeechSynthesisUtterance(text);
        utterance.voice = this._voices[voiceIndex];
        this._speechSynthesis.speak(utterance);
        return true;
    }

}
