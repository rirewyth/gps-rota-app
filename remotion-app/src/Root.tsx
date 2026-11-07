import "./index.css";
import { Composition, Folder } from "remotion";
import { HelloWorld } from "./HelloWorld";
import { Logo } from "./HelloWorld/Logo";
import { Title } from "./HelloWorld/Title";
import { IkiGunesVideo } from "./IkiGunesVideo";
import masterData from "./master_iki_gunes_scenes.json";
import { IstanbulSelVideo } from "./IstanbulSelVideo";
import masterIstanbulData from "./master_istanbul_sel_scenes.json";
import { EditorialSelVideo } from "./EditorialSelVideo";
import editorialSelData from "./editorial_sel_metadata.json";
import { YercekimiVideo } from "./YercekimiVideo";
import yercekimiData from "./yercekimi_metadata.json";
import { YercekimiVideoV2 } from "./YercekimiVideoV2";
import yercekimiV2Data from "./yercekimi_v2_metadata.json";

// Each <Composition> is an entry in the sidebar!

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Folder name="Elements">
        <Composition
          id="Logo"
          component={Logo}
          durationInFrames={150}
          fps={30}
          width={1920}
          height={1080}
          defaultProps={{
            logoColor1: "#91EAE4",
            logoColor2: "#86A8E7",
          }}
        />
        <Composition
          id="Title"
          component={Title}
          durationInFrames={115}
          fps={30}
          width={1920}
          height={1080}
          defaultProps={{
            titleText: "Welcome to Remotion",
            titleColor: "#000000",
          }}
        />
      </Folder>
      <Composition
        // You can take the "id" to render a video:
        // bunx remotion render HelloWorld
        id="HelloWorld"
        component={HelloWorld}
        durationInFrames={150}
        fps={30}
        width={1920}
        height={1080}
        // You can override these props for each render:
        // https://www.remotion.dev/docs/parametrized-rendering
        defaultProps={{
          titleText: "Welcome to Remotion",
          titleColor: "#000000",
        }}
      />
      <Composition
        id="IkiGunes"
        component={IkiGunesVideo}
        durationInFrames={masterData.totalFrames}
        fps={30}
        width={1080}
        height={1920}
      />
      <Composition
        id="IstanbulSel"
        component={IstanbulSelVideo}
        durationInFrames={masterIstanbulData.totalFrames}
        fps={30}
        width={1080}
        height={1920}
      />
      <Composition
        id="EditorialSel"
        component={EditorialSelVideo}
        durationInFrames={editorialSelData.totalFrames}
        fps={30}
        width={1080}
        height={1920}
      />
      <Composition
        id="Yercekimi"
        component={YercekimiVideo}
        durationInFrames={yercekimiData.totalFrames}
        fps={30}
        width={1080}
        height={1920}
      />
      <Composition
        id="YercekimiV2"
        component={YercekimiVideoV2}
        durationInFrames={yercekimiV2Data.totalFrames}
        fps={30}
        width={1080}
        height={1920}
      />
    </>
  );
};
