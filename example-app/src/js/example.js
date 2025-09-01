import { CapacitorUIKit } from 'capacitor-ui-kit';

window.testEcho = () => {
    const inputValue = document.getElementById("echoInput").value;
    CapacitorUIKit.echo({ value: inputValue })
}
